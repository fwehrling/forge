---
name: forge-quick-spec
description: >
  FORGE Quick Track — Spec + direct implementation for bug fixes and small changes.
  Usage: /forge-quick-spec "change description"
---

# /forge-quick-spec — FORGE Quick Track

Fast-track mode for bug fixes and small changes (<1 day).
Skips the planning and architecture phases.

## French Language Rule

All content generated in French MUST use proper accents (é, è, ê, à, ù, ç, ô, î, etc.), follow French grammar rules (agreements, conjugations), and use correct spelling.

## Workflow

1. **Load context** (if FORGE project):
   - Read `.forge/memory/MEMORY.md` for project context (if exists)
   - `forge-memory search "<change description>" --limit 3` (if available)

2. Analyze the request
3. Generate a quick spec (in-memory, no artifact)
4. Write tests (unit + functional for the fix)
5. Implement the change
6. Validate (lint + typecheck + tests)
7. Propose the commit

8. **Save memory** (MANDATORY if FORGE project — never skip):
   ```bash
   forge-memory log "Quick-spec terminé : {DESCRIPTION}, {N} tests" --agent dev
   forge-memory consolidate --verbose
   forge-memory sync
   ```
