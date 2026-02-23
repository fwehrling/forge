"""FORGE Vector Memory — SQLite schema with sqlite-vec and FTS5."""
import sqlite3

import sqlite_vec

from config import EMBEDDING_DIM, EMBEDDING_MODEL

# ---------------------------------------------------------------------------
# Schema SQL
# ---------------------------------------------------------------------------

_SCHEMA_SQL = f"""
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- Core tables ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL UNIQUE,
    namespace TEXT NOT NULL,
    agent TEXT,
    mtime REAL NOT NULL,
    hash TEXT NOT NULL,
    chunk_count INTEGER DEFAULT 0,
    indexed_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    text TEXT NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    heading TEXT,
    token_count INTEGER NOT NULL,
    embedding BLOB NOT NULL
);

-- Vector index (sqlite-vec) -------------------------------------------------

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_vec USING vec0(
    chunk_id INTEGER PRIMARY KEY,
    embedding float[{EMBEDDING_DIM}]
);

-- Full-text search (FTS5) ---------------------------------------------------

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
    text, heading,
    content='chunks', content_rowid='id',
    tokenize='porter unicode61'
);

-- FTS5 synchronisation triggers ---------------------------------------------

CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
    INSERT INTO chunks_fts(rowid, text, heading)
    VALUES (new.id, new.text, new.heading);
END;

CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
    INSERT INTO chunks_fts(chunks_fts, rowid, text, heading)
    VALUES ('delete', old.id, old.text, old.heading);
END;

CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
    INSERT INTO chunks_fts(chunks_fts, rowid, text, heading)
    VALUES ('delete', old.id, old.text, old.heading);
    INSERT INTO chunks_fts(rowid, text, heading)
    VALUES (new.id, new.text, new.heading);
END;

-- Metadata ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""

_META_DEFAULTS = {
    "schema_version": "1",
    "embedding_model": EMBEDDING_MODEL,
    "embedding_dim": str(EMBEDDING_DIM),
}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_connection(db_path: str) -> sqlite3.Connection:
    """Open a connection with sqlite-vec loaded and WAL mode enabled."""
    db = sqlite3.connect(db_path)
    db.enable_load_extension(True)
    sqlite_vec.load(db)
    db.enable_load_extension(False)
    db.execute("PRAGMA journal_mode = WAL")
    db.execute("PRAGMA foreign_keys = ON")
    db.row_factory = sqlite3.Row
    return db


def init_db(db_path: str) -> sqlite3.Connection:
    """Create (or open) the database and ensure the full schema exists.

    Returns an open :class:`sqlite3.Connection`.
    """
    db = get_connection(db_path)
    db.executescript(_SCHEMA_SQL)

    # Insert meta defaults (ignore if already present)
    for key, value in _META_DEFAULTS.items():
        db.execute(
            "INSERT OR IGNORE INTO meta (key, value) VALUES (?, ?)",
            (key, value),
        )
    db.commit()
    return db
