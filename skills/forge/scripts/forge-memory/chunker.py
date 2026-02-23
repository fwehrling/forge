"""FORGE Vector Memory — Markdown-aware chunking.

Splits markdown documents into chunks of approximately CHUNK_SIZE_TOKENS tokens
while preserving heading context and keeping code blocks intact.
"""
from __future__ import annotations

import re
from typing import TypedDict

from config import CHUNK_OVERLAP_TOKENS, CHUNK_SIZE_TOKENS

# Rough token estimation: 1 token ~ 4 characters
_CHARS_PER_TOKEN = 4


class Chunk(TypedDict):
    text: str
    start_line: int
    end_line: int
    heading: str | None
    token_count: int


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _estimate_tokens(text: str) -> int:
    """Estimate the number of tokens in *text*."""
    return max(1, len(text) // _CHARS_PER_TOKEN)


_HEADING_RE = re.compile(r"^(#{2,3})\s+(.+)$")


def _split_into_sections(lines: list[str]) -> list[dict]:
    """Split lines into sections delimited by ## or ### headings.

    Each section is a dict with keys: heading, start_line, lines.
    """
    sections: list[dict] = []
    current_heading: str | None = None
    current_start = 0
    current_lines: list[str] = []

    for idx, line in enumerate(lines):
        m = _HEADING_RE.match(line)
        if m:
            # Flush previous section
            if current_lines:
                sections.append({
                    "heading": current_heading,
                    "start_line": current_start,
                    "lines": current_lines,
                })
            current_heading = line.strip()
            current_start = idx
            current_lines = [line]
        else:
            current_lines.append(line)

    # Flush last section
    if current_lines:
        sections.append({
            "heading": current_heading,
            "start_line": current_start,
            "lines": current_lines,
        })

    return sections


def _is_code_fence(line: str) -> bool:
    stripped = line.strip()
    return stripped.startswith("```")


def _split_section_into_chunks(
    section_lines: list[str],
    section_start_line: int,
    heading: str | None,
    chunk_size: int,
    overlap: int,
) -> list[Chunk]:
    """Split a single section's lines into token-bounded chunks.

    Code blocks (delimited by ```) are never split mid-block.
    Overlap is applied in characters (converted from tokens).
    """
    chunk_size_chars = chunk_size * _CHARS_PER_TOKEN
    overlap_chars = overlap * _CHARS_PER_TOKEN
    chunks: list[Chunk] = []

    # First, group lines into "blocks" — code blocks stay as atomic units,
    # normal lines are individual blocks.
    blocks: list[dict] = []  # {lines: [...], start_line: int, is_code: bool}
    in_code = False
    code_block_lines: list[str] = []
    code_start = 0

    for i, line in enumerate(section_lines):
        abs_line = section_start_line + i
        if _is_code_fence(line):
            if in_code:
                # End of code block
                code_block_lines.append(line)
                blocks.append({
                    "lines": code_block_lines,
                    "start_line": code_start,
                    "is_code": True,
                })
                code_block_lines = []
                in_code = False
            else:
                # Start of code block
                in_code = True
                code_block_lines = [line]
                code_start = abs_line
        elif in_code:
            code_block_lines.append(line)
        else:
            blocks.append({
                "lines": [line],
                "start_line": abs_line,
                "is_code": False,
            })

    # Handle unclosed code block
    if code_block_lines:
        blocks.append({
            "lines": code_block_lines,
            "start_line": code_start,
            "is_code": True,
        })

    # Now assemble blocks into chunks respecting size limits
    current_text_parts: list[str] = []
    current_char_count = 0
    current_start_line = section_start_line
    current_end_line = section_start_line

    def _flush():
        nonlocal current_text_parts, current_char_count
        nonlocal current_start_line, current_end_line
        if not current_text_parts:
            return
        text = "\n".join(current_text_parts)
        if text.strip():
            chunks.append(Chunk(
                text=text,
                start_line=current_start_line,
                end_line=current_end_line,
                heading=heading,
                token_count=_estimate_tokens(text),
            ))
        current_text_parts = []
        current_char_count = 0

    for block in blocks:
        block_text = "\n".join(block["lines"])
        block_chars = len(block_text)
        block_start = block["start_line"]
        block_end = block_start + len(block["lines"]) - 1

        # If a single code block exceeds chunk_size, emit it as its own chunk
        if block["is_code"] and block_chars > chunk_size_chars:
            _flush()
            current_start_line = block_start
            current_end_line = block_end
            current_text_parts = [block_text]
            current_char_count = block_chars
            _flush()
            # Reset start line for next chunk
            if blocks:
                current_start_line = block_end + 1
                current_end_line = block_end + 1
            continue

        # Would adding this block exceed chunk size?
        if current_char_count + block_chars > chunk_size_chars and current_text_parts:
            _flush()
            # Apply overlap: re-include the tail of the previous chunk
            if overlap_chars > 0 and chunks:
                prev_text = chunks[-1]["text"]
                overlap_text = prev_text[-overlap_chars:]
                # Find a clean line break within the overlap region
                newline_pos = overlap_text.find("\n")
                if newline_pos != -1:
                    overlap_text = overlap_text[newline_pos + 1:]
                if overlap_text.strip():
                    current_text_parts = [overlap_text]
                    current_char_count = len(overlap_text)
                    # Adjust start_line: estimate from the previous chunk
                    overlap_lines_count = overlap_text.count("\n") + 1
                    current_start_line = max(
                        section_start_line,
                        chunks[-1]["end_line"] - overlap_lines_count + 1,
                    )
                else:
                    current_start_line = block_start
            else:
                current_start_line = block_start

        if not current_text_parts:
            current_start_line = block_start

        current_text_parts.append(block_text)
        current_char_count += block_chars
        current_end_line = block_end

    _flush()
    return chunks


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def chunk_markdown(
    text: str,
    *,
    chunk_size: int = CHUNK_SIZE_TOKENS,
    overlap: int = CHUNK_OVERLAP_TOKENS,
) -> list[Chunk]:
    """Chunk a markdown document into token-bounded pieces.

    Parameters
    ----------
    text:
        The full markdown document content.
    chunk_size:
        Target chunk size in tokens.
    overlap:
        Overlap between consecutive chunks in tokens.

    Returns
    -------
    A list of :class:`Chunk` dicts with keys:
    ``text``, ``start_line``, ``end_line``, ``heading``, ``token_count``.
    """
    if not text.strip():
        return []

    lines = text.split("\n")
    sections = _split_into_sections(lines)

    all_chunks: list[Chunk] = []
    for section in sections:
        section_chunks = _split_section_into_chunks(
            section_lines=section["lines"],
            section_start_line=section["start_line"],
            heading=section["heading"],
            chunk_size=chunk_size,
            overlap=overlap,
        )
        all_chunks.extend(section_chunks)

    return all_chunks
