"""FORGE Vector Memory — Sentence-transformers embedding pipeline.

Uses a singleton pattern to load the model once and reuse it across calls.
"""
from __future__ import annotations

import threading

import numpy as np
from sentence_transformers import SentenceTransformer

from config import EMBEDDING_DIM, EMBEDDING_MODEL

# ---------------------------------------------------------------------------
# Singleton model loader
# ---------------------------------------------------------------------------

_lock = threading.Lock()
_model: SentenceTransformer | None = None


def _get_model() -> SentenceTransformer:
    """Return the shared SentenceTransformer instance (loaded once)."""
    global _model
    if _model is None:
        with _lock:
            # Double-checked locking
            if _model is None:
                _model = SentenceTransformer(EMBEDDING_MODEL)
    return _model


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def encode(texts: list[str]) -> np.ndarray:
    """Encode a batch of texts into float32 embeddings.

    Parameters
    ----------
    texts:
        List of strings to encode.

    Returns
    -------
    numpy.ndarray of shape ``(len(texts), EMBEDDING_DIM)`` with dtype float32.
    """
    model = _get_model()
    embeddings = model.encode(texts, show_progress_bar=False, convert_to_numpy=True)
    return embeddings.astype(np.float32)


def encode_single(text: str) -> bytes:
    """Encode a single text and return raw bytes suitable for SQLite BLOB storage.

    Parameters
    ----------
    text:
        The string to encode.

    Returns
    -------
    Raw bytes of the float32 embedding vector.
    """
    model = _get_model()
    embedding = model.encode([text], show_progress_bar=False, convert_to_numpy=True)
    return embedding[0].astype(np.float32).tobytes()


def encode_batch(texts: list[str]) -> list[bytes]:
    """Encode a batch of texts and return a list of raw bytes blobs.

    Parameters
    ----------
    texts:
        List of strings to encode.

    Returns
    -------
    List of raw bytes, one per input text.
    """
    embeddings = encode(texts)
    return [row.tobytes() for row in embeddings]


def blob_to_array(blob: bytes) -> np.ndarray:
    """Convert a raw bytes blob back to a numpy float32 array.

    Parameters
    ----------
    blob:
        Raw bytes (from SQLite BLOB column).

    Returns
    -------
    numpy.ndarray of shape ``(EMBEDDING_DIM,)`` with dtype float32.
    """
    return np.frombuffer(blob, dtype=np.float32).copy()
