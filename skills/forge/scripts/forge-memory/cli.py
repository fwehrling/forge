#!/usr/bin/env python3
"""FORGE Vector Memory — CLI entry point.

Usage:
    forge-memory sync   [--force] [--verbose]
    forge-memory search "query" [--namespace ...] [--agent ...] [--limit N] [--threshold F] [--pretty]
    forge-memory status [--json]
    forge-memory reset  --confirm
    forge-memory log    "message" [--agent NAME] [--story STORY-ID]
    forge-memory consolidate [--verbose]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

# ---------------------------------------------------------------------------
# Ensure package directory is on sys.path so sibling imports work when
# invoked as a standalone script (not via ``python -m``).
# ---------------------------------------------------------------------------
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

from config import get_db_path, get_memory_dir
from consolidate import consolidate as do_consolidate
from db import get_connection, init_db
from logger import log as do_log
from search import search as do_search
from sync import sync as do_sync


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_project_root() -> str:
    """Walk up from CWD looking for a directory that contains .forge/memory/.

    Raises SystemExit if none is found.
    """
    current = os.getcwd()
    while True:
        candidate = os.path.join(current, ".forge", "memory")
        if os.path.isdir(candidate):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            print("Error: could not find .forge/memory/ in any parent directory.", file=sys.stderr)
            sys.exit(1)
        current = parent


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_sync(args: argparse.Namespace) -> None:
    """Synchronise markdown files into the vector index."""
    root = _find_project_root()
    if args.verbose:
        print(f"Project root: {root}")
        print(f"Memory dir:   {get_memory_dir(root)}")
        print()

    stats = do_sync(root, force=args.force, verbose=args.verbose)

    print()
    print(f"Sync complete: "
          f"+{stats['added']} added, "
          f"~{stats['updated']} updated, "
          f"-{stats['deleted']} deleted, "
          f"={stats['unchanged']} unchanged")


def cmd_search(args: argparse.Namespace) -> None:
    """Run a hybrid search query."""
    root = _find_project_root()

    ns = args.namespace if args.namespace != "all" else None
    results = do_search(
        root,
        args.query,
        namespace=ns,
        agent=args.agent,
        limit=args.limit,
        threshold=args.threshold,
    )

    if args.pretty:
        if not results:
            print("No results found.")
            return
        for i, r in enumerate(results, 1):
            print(f"\n{'='*60}")
            print(f"Result {i}/{len(results)}  (score: {r['score']:.4f})")
            print(f"File:      {r['file']}")
            print(f"Namespace: {r['namespace']}")
            if r["heading"]:
                print(f"Heading:   {r['heading']}")
            print(f"Lines:     {r['start_line']}-{r['end_line']}")
            print(f"{'-'*60}")
            print(r["text"])
        print(f"\n{'='*60}")
        print(f"{len(results)} result(s)")
    else:
        output = {"results": results}
        print(json.dumps(output, indent=2, ensure_ascii=False))


def cmd_status(args: argparse.Namespace) -> None:
    """Show index status information."""
    root = _find_project_root()
    db_path = get_db_path(root)

    info: dict = {
        "project_root": root,
        "memory_dir": get_memory_dir(root),
        "db_path": db_path,
        "db_exists": os.path.exists(db_path),
    }

    if not info["db_exists"]:
        info["file_count"] = 0
        info["chunk_count"] = 0
        info["namespaces"] = {}
        info["db_size_bytes"] = 0
        info["model"] = None
    else:
        db = get_connection(db_path)

        file_count = db.execute("SELECT COUNT(*) AS c FROM files").fetchone()["c"]
        chunk_count = db.execute("SELECT COUNT(*) AS c FROM chunks").fetchone()["c"]

        ns_rows = db.execute(
            "SELECT namespace, COUNT(*) AS c FROM files GROUP BY namespace"
        ).fetchall()
        namespaces = {row["namespace"]: row["c"] for row in ns_rows}

        meta_rows = db.execute("SELECT key, value FROM meta").fetchall()
        meta = {row["key"]: row["value"] for row in meta_rows}

        db_size = os.path.getsize(db_path)

        info.update({
            "file_count": file_count,
            "chunk_count": chunk_count,
            "namespaces": namespaces,
            "db_size_bytes": db_size,
            "db_size_human": _human_size(db_size),
            "model": meta.get("embedding_model"),
            "embedding_dim": meta.get("embedding_dim"),
            "schema_version": meta.get("schema_version"),
        })
        db.close()

    if args.json:
        print(json.dumps(info, indent=2, ensure_ascii=False))
    else:
        print(f"FORGE Vector Memory — Status")
        print(f"{'='*40}")
        print(f"Project root:    {info['project_root']}")
        print(f"Database:        {info['db_path']}")
        if info["db_exists"]:
            print(f"Database size:   {info.get('db_size_human', 'N/A')}")
            print(f"Model:           {info.get('model', 'N/A')}")
            print(f"Embedding dim:   {info.get('embedding_dim', 'N/A')}")
            print(f"Schema version:  {info.get('schema_version', 'N/A')}")
            print(f"Files indexed:   {info['file_count']}")
            print(f"Total chunks:    {info['chunk_count']}")
            print(f"Namespaces:")
            for ns, count in info["namespaces"].items():
                print(f"  {ns:12s}  {count} file(s)")
        else:
            print(f"Database does not exist yet. Run 'forge-memory sync' first.")


def cmd_log(args: argparse.Namespace) -> None:
    """Append a log entry to today's session file."""
    root = _find_project_root()
    filepath = do_log(
        root,
        args.message,
        agent=args.agent,
        story=args.story,
    )
    print(f"Logged to {filepath}")


def cmd_consolidate(args: argparse.Namespace) -> None:
    """Consolidate session logs into MEMORY.md."""
    root = _find_project_root()
    count = do_consolidate(root, verbose=args.verbose)
    if count:
        print(f"Consolidation complete: {count} entries merged into MEMORY.md")
    else:
        print("Nothing to consolidate.")


def cmd_reset(args: argparse.Namespace) -> None:
    """Drop and recreate the database."""
    if not args.confirm:
        print("Error: --confirm flag required to reset the database.", file=sys.stderr)
        sys.exit(1)

    root = _find_project_root()
    db_path = get_db_path(root)

    if os.path.exists(db_path):
        os.remove(db_path)
        # Also remove WAL and SHM files if present
        for suffix in ("-wal", "-shm"):
            wal_path = db_path + suffix
            if os.path.exists(wal_path):
                os.remove(wal_path)
        print(f"Deleted: {db_path}")

    init_db(db_path)
    print("Database recreated (empty).")


def _human_size(size_bytes: int) -> str:
    """Format a byte count into a human-readable string."""
    for unit in ("B", "KB", "MB", "GB"):
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} TB"


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="forge-memory",
        description="FORGE Vector Memory — index and search .forge/memory/ markdown files.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # sync -------------------------------------------------------------------
    p_sync = sub.add_parser("sync", help="Synchronise markdown files into the index.")
    p_sync.add_argument("--force", action="store_true", help="Re-index all files regardless of hash.")
    p_sync.add_argument("--verbose", action="store_true", help="Print progress info.")

    # search -----------------------------------------------------------------
    p_search = sub.add_parser("search", help="Run a hybrid vector+FTS search.")
    p_search.add_argument("query", help="Natural-language search query.")
    p_search.add_argument("--namespace", default="all",
                          choices=["all", "project", "session", "agent"],
                          help="Filter by namespace (default: all).")
    p_search.add_argument("--agent", default=None, help="Filter by agent name.")
    p_search.add_argument("--limit", type=int, default=5, help="Max results (default: 5).")
    p_search.add_argument("--threshold", type=float, default=0.3, help="Min score threshold (default: 0.3).")
    p_search.add_argument("--pretty", action="store_true", help="Pretty-print instead of JSON.")

    # status -----------------------------------------------------------------
    p_status = sub.add_parser("status", help="Show index status.")
    p_status.add_argument("--json", action="store_true", help="Output as JSON.")

    # log --------------------------------------------------------------------
    p_log = sub.add_parser("log", help="Append a log entry to today's session file.")
    p_log.add_argument("message", help="The log message.")
    p_log.add_argument("--agent", default=None, help="Agent name (e.g. dev, qa, lead).")
    p_log.add_argument("--story", default=None, help="Story ID (e.g. STORY-003).")

    # consolidate ------------------------------------------------------------
    p_consolidate = sub.add_parser("consolidate", help="Consolidate session logs into MEMORY.md.")
    p_consolidate.add_argument("--verbose", action="store_true", help="Print progress info.")

    # reset ------------------------------------------------------------------
    p_reset = sub.add_parser("reset", help="Drop and recreate the database.")
    p_reset.add_argument("--confirm", action="store_true", help="Required to confirm reset.")

    return parser


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "sync": cmd_sync,
        "search": cmd_search,
        "status": cmd_status,
        "log": cmd_log,
        "consolidate": cmd_consolidate,
        "reset": cmd_reset,
    }

    handler = dispatch.get(args.command)
    if handler:
        handler(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
