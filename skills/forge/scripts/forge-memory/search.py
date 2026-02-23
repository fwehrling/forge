"""FORGE Vector Memory — Hybrid vector + FTS5 search.

Combines cosine-similarity vector search (via sqlite-vec) with BM25 full-text
search (via FTS5) using weighted score fusion.
"""
from __future__ import annotations

import os
from typing import Any, TypedDict

import numpy as np

from config import (
    DEFAULT_LIMIT,
    DEFAULT_THRESHOLD,
    FTS_WEIGHT,
    VECTOR_WEIGHT,
    get_db_path,
    get_extra_scan_dirs,
    get_memory_dir,
)
from db import get_connection, init_db
from embedder import encode_single
from sync import sync


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

class SearchResult(TypedDict):
    text: str
    file: str
    namespace: str
    heading: str | None
    start_line: int
    end_line: int
    score: float


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _should_auto_sync(project_root: str) -> bool:
    """Return True if any .md file has been modified, added, or deleted since the last sync."""
    db_path = get_db_path(project_root)
    memory_dir = get_memory_dir(project_root)

    if not os.path.exists(db_path):
        return True

    db = get_connection(db_path)
    rows = db.execute("SELECT path, mtime FROM files").fetchall()
    db.close()
    stored_mtimes = {row["path"]: row["mtime"] for row in rows}

    # Collect disk files with their mtimes (relative paths matching sync.py convention)
    disk_mtimes: dict[str, float] = {}
    dirs_to_check = [memory_dir] + get_extra_scan_dirs(project_root)
    for scan_dir in dirs_to_check:
        if not os.path.isdir(scan_dir):
            continue
        for dirpath, _dirs, filenames in os.walk(scan_dir):
            for fname in filenames:
                if fname.lower().endswith(".md"):
                    fpath = os.path.join(dirpath, fname)
                    rel_path = os.path.relpath(fpath, project_root)
                    disk_mtimes[rel_path] = os.path.getmtime(fpath)

    # Detect additions or deletions (different file sets)
    if set(disk_mtimes.keys()) != set(stored_mtimes.keys()):
        return True

    # Detect modifications (mtime changed since last sync)
    for path, disk_mtime in disk_mtimes.items():
        if disk_mtime != stored_mtimes[path]:
            return True

    return False


def _normalise_fts_query(query: str) -> str:
    """Prepare a query string for FTS5 MATCH.

    FTS5 expects terms; we quote each word to avoid syntax issues with
    special characters, then join with OR for a broad match.
    """
    words = query.split()
    if not words:
        return '""'
    # Quote each token and join with OR
    quoted = [f'"{w}"' for w in words if w.strip()]
    return " OR ".join(quoted)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def search(
    project_root: str,
    query: str,
    *,
    namespace: str | None = None,
    agent: str | None = None,
    limit: int = DEFAULT_LIMIT,
    threshold: float = DEFAULT_THRESHOLD,
) -> list[SearchResult]:
    """Run a hybrid vector + FTS5 search over the memory index.

    Parameters
    ----------
    project_root:
        Absolute path to the project root.
    query:
        Natural-language search query.
    namespace:
        Filter results to a specific namespace (``project``, ``session``,
        ``agent``). ``None`` or ``"all"`` returns all namespaces.
    agent:
        Filter results to a specific agent name (only meaningful when
        namespace is ``agent`` or ``None``).
    limit:
        Maximum number of results to return.
    threshold:
        Minimum fused score to include in results (0..1).

    Returns
    -------
    List of :class:`SearchResult` dicts sorted by descending score.
    """
    if not query.strip():
        return []

    # Auto-sync if needed
    if _should_auto_sync(project_root):
        sync(project_root)

    db_path = get_db_path(project_root)
    if not os.path.exists(db_path):
        return []

    db = get_connection(db_path)

    # Expanded fetch window
    fetch_limit = limit * 3

    # -----------------------------------------------------------------------
    # 1. Vector search
    # -----------------------------------------------------------------------
    query_blob = encode_single(query)
    vec_rows = db.execute(
        "SELECT chunk_id, distance FROM chunks_vec "
        "WHERE embedding MATCH ? ORDER BY distance LIMIT ?",
        (query_blob, fetch_limit),
    ).fetchall()

    vec_scores: dict[int, float] = {}
    if vec_rows:
        max_dist = max(row["distance"] for row in vec_rows) or 1.0
        for row in vec_rows:
            # Normalise: 0 distance → score 1.0, max distance → score 0.0
            vec_scores[row["chunk_id"]] = 1.0 - (row["distance"] / max_dist) if max_dist > 0 else 1.0

    # -----------------------------------------------------------------------
    # 2. FTS5 search
    # -----------------------------------------------------------------------
    fts_query = _normalise_fts_query(query)
    fts_scores: dict[int, float] = {}
    try:
        fts_rows = db.execute(
            "SELECT rowid, rank FROM chunks_fts WHERE chunks_fts MATCH ? "
            "ORDER BY rank LIMIT ?",
            (fts_query, fetch_limit),
        ).fetchall()
        if fts_rows:
            # rank is negative (more negative = better). Normalise to [0, 1].
            min_rank = min(row["rank"] for row in fts_rows)  # most negative
            max_rank = max(row["rank"] for row in fts_rows)  # least negative
            range_rank = max_rank - min_rank if max_rank != min_rank else 1.0
            for row in fts_rows:
                # Best match (most negative rank) → 1.0
                fts_scores[row["rowid"]] = (max_rank - row["rank"]) / range_rank
    except Exception:
        # FTS query may fail on unusual input — degrade gracefully
        pass

    # -----------------------------------------------------------------------
    # 3. Fuse scores
    # -----------------------------------------------------------------------
    all_chunk_ids = set(vec_scores.keys()) | set(fts_scores.keys())
    fused: list[tuple[int, float]] = []
    for cid in all_chunk_ids:
        vs = vec_scores.get(cid, 0.0)
        fs = fts_scores.get(cid, 0.0)
        score = VECTOR_WEIGHT * vs + FTS_WEIGHT * fs
        if score >= threshold:
            fused.append((cid, score))

    fused.sort(key=lambda x: x[1], reverse=True)

    # -----------------------------------------------------------------------
    # 4. Fetch chunk metadata and apply filters
    # -----------------------------------------------------------------------
    results: list[SearchResult] = []
    for chunk_id, score in fused:
        if len(results) >= limit:
            break

        row = db.execute(
            """SELECT c.text, c.start_line, c.end_line, c.heading,
                      f.path, f.namespace, f.agent
               FROM chunks c
               JOIN files f ON c.file_id = f.id
               WHERE c.id = ?""",
            (chunk_id,),
        ).fetchone()

        if row is None:
            continue

        # Namespace filter
        if namespace and namespace != "all" and row["namespace"] != namespace:
            continue

        # Agent filter
        if agent and row["agent"] != agent:
            continue

        results.append(SearchResult(
            text=row["text"],
            file=row["path"],
            namespace=row["namespace"],
            heading=row["heading"],
            start_line=row["start_line"],
            end_line=row["end_line"],
            score=round(score, 4),
        ))

    db.close()
    return results
