"""FORGE Vector Memory — Configuration"""
import os

# Embedding model
EMBEDDING_MODEL = "all-MiniLM-L6-v2"
EMBEDDING_DIM = 384

# Chunking
CHUNK_SIZE_TOKENS = int(os.environ.get("FORGE_CHUNK_SIZE", "400"))
CHUNK_OVERLAP_TOKENS = int(os.environ.get("FORGE_CHUNK_OVERLAP", "80"))

# Search
VECTOR_WEIGHT = float(os.environ.get("FORGE_VECTOR_WEIGHT", "0.7"))
FTS_WEIGHT = float(os.environ.get("FORGE_FTS_WEIGHT", "0.3"))
DEFAULT_LIMIT = int(os.environ.get("FORGE_SEARCH_LIMIT", "5"))
DEFAULT_THRESHOLD = float(os.environ.get("FORGE_SEARCH_THRESHOLD", "0.3"))

# Paths (relative to project root)
MEMORY_DIR = ".forge/memory"
DB_FILENAME = "index.sqlite"

# Additional directories to scan (relative to project root)
EXTRA_SCAN_DIRS = ["docs"]


def get_memory_dir(project_root: str) -> str:
    """Return absolute path to the .forge/memory/ directory."""
    return os.path.join(project_root, MEMORY_DIR)


def get_db_path(project_root: str) -> str:
    """Return absolute path to the SQLite database file."""
    return os.path.join(project_root, MEMORY_DIR, DB_FILENAME)


def get_extra_scan_dirs(project_root: str) -> list[str]:
    """Return absolute paths to extra directories to scan for markdown files."""
    dirs = []
    for d in EXTRA_SCAN_DIRS:
        abs_d = os.path.join(project_root, d)
        if os.path.isdir(abs_d):
            dirs.append(abs_d)
    return dirs
