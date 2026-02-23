"""FORGE Vector Memory — Markdown to SQLite synchronisation.

Scans .forge/memory/ for markdown files, detects changes via SHA-256 hashes,
and re-indexes only modified or new files.
"""
from __future__ import annotations

import hashlib
import os
from typing import TypedDict

from chunker import chunk_markdown
from config import get_db_path, get_extra_scan_dirs, get_memory_dir
from db import get_connection, init_db
from embedder import encode_batch


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

class SyncStats(TypedDict):
    added: int
    updated: int
    deleted: int
    unchanged: int


class FileInfo(TypedDict):
    path: str          # Relative to project root (e.g. .forge/memory/MEMORY.md)
    abs_path: str      # Absolute path on disk
    namespace: str     # project | session | agent
    agent: str | None  # Agent name (only for namespace=agent)
    mtime: float
    hash: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def compute_hash(filepath: str) -> str:
    """Compute the SHA-256 hex digest of a file's content."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for block in iter(lambda: f.read(8192), b""):
            h.update(block)
    return h.hexdigest()


def _detect_namespace(rel_path: str) -> tuple[str, str | None]:
    """Detect namespace and optional agent name from a relative path.

    Rules:
      - MEMORY.md (at root of memory dir) → 'project'
      - sessions/*.md → 'session'
      - agents/*.md → 'agent' with name extracted from filename
      - anything else → 'project'
    """
    # Normalise separators
    parts = rel_path.replace("\\", "/").split("/")

    basename = parts[-1]

    if len(parts) == 1 and basename.upper() == "MEMORY.MD":
        return "project", None

    if len(parts) >= 2:
        folder = parts[0].lower()
        if folder == "sessions":
            return "session", None
        if folder == "agents":
            agent_name = os.path.splitext(basename)[0]
            return "agent", agent_name

    return "project", None


def scan_files(
    source_dir: str,
    project_root: str,
    *,
    namespace_override: str | None = None,
) -> list[FileInfo]:
    """Recursively scan *source_dir* for .md files and return metadata.

    Parameters
    ----------
    source_dir:
        Directory to scan.
    project_root:
        Project root (used for relative paths).
    namespace_override:
        If set, force this namespace for all discovered files instead of
        auto-detecting from path structure.
    """
    results: list[FileInfo] = []
    for dirpath, _dirs, filenames in os.walk(source_dir):
        for fname in filenames:
            if not fname.lower().endswith(".md"):
                continue
            abs_path = os.path.join(dirpath, fname)
            rel_to_source = os.path.relpath(abs_path, source_dir)
            rel_to_root = os.path.relpath(abs_path, project_root)

            if namespace_override:
                namespace, agent = namespace_override, None
            else:
                namespace, agent = _detect_namespace(rel_to_source)

            results.append(FileInfo(
                path=rel_to_root,
                abs_path=abs_path,
                namespace=namespace,
                agent=agent,
                mtime=os.path.getmtime(abs_path),
                hash=compute_hash(abs_path),
            ))
    return results


# ---------------------------------------------------------------------------
# Core sync logic
# ---------------------------------------------------------------------------

def _index_file(db, file_info: FileInfo) -> int:
    """Chunk, embed and insert a single file. Return chunk count."""
    with open(file_info["abs_path"], "r", encoding="utf-8") as f:
        content = f.read()

    chunks = chunk_markdown(content)
    if not chunks:
        return 0

    # Embed all chunks in a single batch
    texts = [c["text"] for c in chunks]
    blobs = encode_batch(texts)

    # Insert file record
    cur = db.execute(
        """INSERT INTO files (path, namespace, agent, mtime, hash, chunk_count)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (
            file_info["path"],
            file_info["namespace"],
            file_info["agent"],
            file_info["mtime"],
            file_info["hash"],
            len(chunks),
        ),
    )
    file_id = cur.lastrowid

    # Insert chunks + vector rows
    for idx, (chunk, blob) in enumerate(zip(chunks, blobs)):
        cur2 = db.execute(
            """INSERT INTO chunks
               (file_id, chunk_index, text, start_line, end_line, heading, token_count, embedding)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                file_id,
                idx,
                chunk["text"],
                chunk["start_line"],
                chunk["end_line"],
                chunk["heading"],
                chunk["token_count"],
                blob,
            ),
        )
        chunk_id = cur2.lastrowid
        db.execute(
            "INSERT INTO chunks_vec (chunk_id, embedding) VALUES (?, ?)",
            (chunk_id, blob),
        )

    return len(chunks)


def _delete_file(db, file_path: str) -> None:
    """Delete a file and all its chunks (cascading) from the database."""
    row = db.execute("SELECT id FROM files WHERE path = ?", (file_path,)).fetchone()
    if row is None:
        return
    file_id = row["id"]

    # Delete vector rows first (no cascade on virtual table)
    db.execute(
        "DELETE FROM chunks_vec WHERE chunk_id IN (SELECT id FROM chunks WHERE file_id = ?)",
        (file_id,),
    )
    # Cascade will clean chunks + FTS via triggers
    db.execute("DELETE FROM files WHERE id = ?", (file_id,))


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def sync(
    project_root: str,
    *,
    force: bool = False,
    verbose: bool = False,
) -> SyncStats:
    """Synchronise .forge/memory/ markdown files into the SQLite index.

    Parameters
    ----------
    project_root:
        Absolute path to the project root containing .forge/memory/.
    force:
        If ``True``, re-index all files regardless of hash changes.
    verbose:
        If ``True``, print progress information.

    Returns
    -------
    A dict with keys: added, updated, deleted, unchanged.
    """
    memory_dir = get_memory_dir(project_root)
    db_path = get_db_path(project_root)

    if not os.path.isdir(memory_dir):
        raise FileNotFoundError(f"Memory directory not found: {memory_dir}")

    db = init_db(db_path)

    stats: SyncStats = {"added": 0, "updated": 0, "deleted": 0, "unchanged": 0}

    # Scan files on disk — memory dir + extra dirs
    disk_files = scan_files(memory_dir, project_root)
    for extra_dir in get_extra_scan_dirs(project_root):
        disk_files.extend(
            scan_files(extra_dir, project_root, namespace_override="project")
        )
    disk_map = {fi["path"]: fi for fi in disk_files}

    # Get current state from DB
    db_rows = db.execute("SELECT id, path, hash FROM files").fetchall()
    db_map = {row["path"]: dict(row) for row in db_rows}

    # Detect deleted files (in DB but not on disk)
    for db_path_key in list(db_map.keys()):
        if db_path_key not in disk_map:
            if verbose:
                print(f"  - Deleted: {db_path_key}")
            _delete_file(db, db_path_key)
            stats["deleted"] += 1

    # Process files on disk
    for rel_path, file_info in disk_map.items():
        if rel_path in db_map:
            if not force and file_info["hash"] == db_map[rel_path]["hash"]:
                stats["unchanged"] += 1
                continue
            # Updated file
            if verbose:
                print(f"  ~ Updated: {rel_path}")
            _delete_file(db, rel_path)
            count = _index_file(db, file_info)
            if verbose:
                print(f"    ({count} chunks)")
            stats["updated"] += 1
        else:
            # New file
            if verbose:
                print(f"  + Added: {rel_path}")
            count = _index_file(db, file_info)
            if verbose:
                print(f"    ({count} chunks)")
            stats["added"] += 1

    db.commit()
    db.close()
    return stats
