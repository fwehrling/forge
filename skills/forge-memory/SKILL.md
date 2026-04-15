---
name: forge-memory
description: >
  Vector memory diagnostic -- sync, search, status, reset, log, consolidate.
---

# /forge-memory -- FORGE Vector Memory

Diagnostic tool for the FORGE vector memory index.
FORGE commands use vector search automatically; this skill is for diagnostics and maintenance.

## Prerequisites

The system must be installed:
```bash
bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh
```

## Commands

### Sync index

Synchronizes Markdown files to the SQLite database:

```bash
forge-memory sync [--force] [--verbose]
```

- Without `--force`: re-indexes only modified files (based on SHA-256 hash)
- With `--force`: re-indexes all files
- With `--verbose`: displays details for each processed file

### Search

Hybrid search (vector + text) in memory:

```bash
forge-memory search "query" [--namespace all|project|session|agent] [--agent NAME] [--limit 5] [--threshold 0.3] [--pretty]
```

- `--namespace`: filter by type (project = MEMORY.md, session = logs, agent = agent memories)
- `--agent`: filter by agent name (pm, architect, dev, qa)
- `--limit`: max number of results (default: 5)
- `--threshold`: minimum score (default: 0.3)
- `--pretty`: formatted output (otherwise JSON)

### Status

Displays index statistics:

```bash
forge-memory status [--json]
```

### Log

Adds an entry to the current day's session file (`.forge/memory/sessions/YYYY-MM-DD.md`):

```bash
forge-memory log "message" [--agent NAME] [--story STORY-ID]
```

- `--agent`: agent name (dev, qa, lead, etc.)
- `--story`: story identifier (STORY-001, etc.)
- Creates the `sessions/` directory and file with automatic header

### Consolidate

Aggregates session log entries into MEMORY.md, grouped by story:

```bash
forge-memory consolidate [--verbose]
```

- Reads sessions since last consolidation (marker `### Consolidation -- YYYY-MM-DD`)
- Appends a summary section at the end of MEMORY.md
- Pure Python, no LLM dependency

### Reset

Deletes and recreates the database:

```bash
forge-memory reset --confirm
```

## Architecture

```
.forge/memory/
  MEMORY.md              <- source of truth (written by agents)
  sessions/YYYY-MM-DD.md <- source of truth (written by agents)
  agents/{agent}.md      <- source of truth (written by agents)
  index.sqlite           <- derived index (synchronized from .md files)
```

- One-way synchronization: Markdown -> SQLite
- Extended sync scope: `.forge/memory/` + `docs/` (stories, architecture, PRD)
- Auto-sync before each search (checks for changes in both directories)
- Hybrid search: vector similarity (70%) + FTS5 BM25 (30%)
- Local embeddings: sentence-transformers all-MiniLM-L6-v2 (384 dimensions)
- Markdown-aware chunking: ~400 tokens/chunk, 80 tokens overlap

## Output Examples

### `forge-memory status`

```
FORGE Memory -- Status
----------------------
Database  : .forge/memory/index.sqlite
Documents : 42 indexed (12 project, 18 session, 12 agent)
Chunks    : 187 total
Last sync : 2026-03-08 14:23:01
Model     : all-MiniLM-L6-v2 (384 dims)
```

### `forge-memory search "auth" --pretty`

```
[0.87] .forge/memory/sessions/2026-03-07.md:12
  "JWT auth implemented with refresh tokens, 15min expiry..."

[0.72] docs/architecture.md:45
  "Authentication uses bcrypt + JWT. Session management via..."

[0.65] .forge/memory/MEMORY.md:23
  "STORY-002 auth: learned that httpOnly cookies are required..."
```
