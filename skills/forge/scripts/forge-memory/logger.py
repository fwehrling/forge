"""FORGE Vector Memory — Session logger.

Appends timestamped entries to .forge/memory/sessions/YYYY-MM-DD.md.
"""
from __future__ import annotations

import os
from datetime import datetime


def _sessions_dir(project_root: str) -> str:
    """Return absolute path to the sessions directory."""
    return os.path.join(project_root, ".forge", "memory", "sessions")


def _today_file(project_root: str) -> str:
    """Return absolute path to today's session log."""
    return os.path.join(_sessions_dir(project_root), f"{datetime.now():%Y-%m-%d}.md")


def _ensure_session_file(filepath: str) -> None:
    """Create the session file with a header if it does not exist."""
    dirpath = os.path.dirname(filepath)
    os.makedirs(dirpath, exist_ok=True)

    if not os.path.exists(filepath):
        date_str = os.path.splitext(os.path.basename(filepath))[0]
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# Session — {date_str}\n\n")


def log(
    project_root: str,
    message: str,
    *,
    agent: str | None = None,
    story: str | None = None,
) -> str:
    """Append a log entry to today's session file.

    Parameters
    ----------
    project_root:
        Absolute path to the project root containing .forge/memory/.
    message:
        The log message text.
    agent:
        Optional agent name (e.g. ``dev``, ``qa``).
    story:
        Optional story ID (e.g. ``STORY-003``).

    Returns
    -------
    The absolute path to the session file written to.
    """
    filepath = _today_file(project_root)
    _ensure_session_file(filepath)

    now = datetime.now()
    timestamp = now.strftime("%H:%M:%S")

    # Build the entry
    parts: list[str] = [f"- **{timestamp}**"]
    if agent:
        parts.append(f" [{agent}]")
    if story:
        parts.append(f" ({story})")
    parts.append(f" — {message}")

    entry = "".join(parts) + "\n"

    with open(filepath, "a", encoding="utf-8") as f:
        f.write(entry)

    return filepath
