"""FORGE Vector Memory — Session log consolidation.

Reads session logs since the last consolidation and appends an aggregated
summary section to MEMORY.md, grouped by story.
"""
from __future__ import annotations

import os
import re
from datetime import datetime


# Regex to match a session log entry line
_ENTRY_RE = re.compile(
    r"^- \*\*(\d{2}:\d{2}:\d{2})\*\*"
    r"(?:\s*\[([^\]]*)\])?"       # optional [agent]
    r"(?:\s*\(([^)]*)\))?"        # optional (STORY-XXX)
    r"\s*—\s*(.+)$"
)

# Marker in MEMORY.md to detect the last consolidation date
_CONSOLIDATION_MARKER_RE = re.compile(
    r"^### Consolidation — (\d{4}-\d{2}-\d{2})"
)


def _find_last_consolidation_date(memory_path: str) -> str | None:
    """Scan MEMORY.md for the most recent consolidation marker.

    Returns the date string (YYYY-MM-DD) or None if never consolidated.
    """
    if not os.path.exists(memory_path):
        return None

    last_date: str | None = None
    with open(memory_path, "r", encoding="utf-8") as f:
        for line in f:
            m = _CONSOLIDATION_MARKER_RE.match(line.strip())
            if m:
                last_date = m.group(1)
    return last_date


def _list_session_files(sessions_dir: str, after_date: str | None) -> list[str]:
    """Return sorted list of session file paths newer than *after_date*.

    If *after_date* is None, return all session files.
    """
    if not os.path.isdir(sessions_dir):
        return []

    files: list[str] = []
    for fname in sorted(os.listdir(sessions_dir)):
        if not fname.endswith(".md"):
            continue
        file_date = os.path.splitext(fname)[0]  # YYYY-MM-DD
        if after_date and file_date <= after_date:
            continue
        files.append(os.path.join(sessions_dir, fname))
    return files


def _parse_entries(filepath: str) -> list[dict]:
    """Parse a session file and return structured entries."""
    entries: list[dict] = []
    date_str = os.path.splitext(os.path.basename(filepath))[0]

    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            m = _ENTRY_RE.match(line.strip())
            if m:
                entries.append({
                    "date": date_str,
                    "time": m.group(1),
                    "agent": m.group(2),
                    "story": m.group(3),
                    "message": m.group(4),
                })
    return entries


def consolidate(
    project_root: str,
    *,
    verbose: bool = False,
) -> int:
    """Consolidate session logs into MEMORY.md.

    Reads session logs created after the last consolidation date,
    groups entries by story, and appends a summary section to MEMORY.md.

    Parameters
    ----------
    project_root:
        Absolute path to the project root.
    verbose:
        If True, print progress information.

    Returns
    -------
    The number of entries consolidated.
    """
    memory_dir = os.path.join(project_root, ".forge", "memory")
    memory_path = os.path.join(memory_dir, "MEMORY.md")
    sessions_dir = os.path.join(memory_dir, "sessions")

    last_date = _find_last_consolidation_date(memory_path)
    if verbose:
        print(f"Last consolidation: {last_date or 'never'}")

    session_files = _list_session_files(sessions_dir, last_date)
    if not session_files:
        if verbose:
            print("No new session logs to consolidate.")
        return 0

    if verbose:
        print(f"Found {len(session_files)} session file(s) to consolidate")

    # Collect all entries
    all_entries: list[dict] = []
    for fpath in session_files:
        entries = _parse_entries(fpath)
        if verbose:
            print(f"  {os.path.basename(fpath)}: {len(entries)} entries")
        all_entries.extend(entries)

    if not all_entries:
        if verbose:
            print("No entries found in session files.")
        return 0

    # Group by story (None for entries without a story)
    by_story: dict[str | None, list[dict]] = {}
    for entry in all_entries:
        key = entry["story"]
        by_story.setdefault(key, []).append(entry)

    # Build the consolidation section
    today = datetime.now().strftime("%Y-%m-%d")
    lines: list[str] = [
        "",
        f"### Consolidation — {today}",
        "",
    ]

    # Stories first (sorted), then general entries
    story_keys = sorted(k for k in by_story if k is not None)
    if None in by_story:
        story_keys.append(None)

    for story_key in story_keys:
        entries = by_story[story_key]
        if story_key:
            lines.append(f"**{story_key}**:")
        else:
            lines.append("**Général**:")

        for e in entries:
            agent_tag = f" [{e['agent']}]" if e["agent"] else ""
            lines.append(f"- {e['date']} {e['time']}{agent_tag} — {e['message']}")
        lines.append("")

    # Append to MEMORY.md
    os.makedirs(memory_dir, exist_ok=True)
    with open(memory_path, "a", encoding="utf-8") as f:
        f.write("\n".join(lines))

    if verbose:
        print(f"Consolidated {len(all_entries)} entries into MEMORY.md")

    return len(all_entries)
