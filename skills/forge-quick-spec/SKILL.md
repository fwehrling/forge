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

2. **Classify the request**: Bug fix or small feature change?

### Bug Fix Track

3. **Root cause analysis** (in-memory, no artifact):
   - **Reproduce**: Steps to reproduce, expected vs. actual behavior
   - **Identify cause**: Pinpoint the root cause (not just the symptom)
   - **Affected components**: Frontend / Backend / Database / External services
   - **Code location**: File path, function/method, line range

4. **Impact & risk assessment**:
   - **Severity**: Blocker / Major / Minor / Trivial
   - **Affected users**: Scope of impact
   - **Side effects**: What else could this fix break?
   - **Rollback plan**: How to revert if the fix causes regression

5. **Write regression tests first** (TDD):
   - Test that reproduces the bug (must fail before fix)
   - Unit tests for the fix
   - Functional test covering the user flow

6. **Implement the fix**

7. **Validate**:
   - Regression test now passes
   - All pre-existing tests still pass (non-regression)
   - Lint + typecheck clean
   - Side effects verified

8. **Propose the commit** (format: `fix: <description>`)

### Small Change Track

3. **Analyze the request**
4. **Generate a quick spec** (in-memory, no artifact)
5. **Write tests** (unit + functional for the change)
6. **Implement the change**
7. **Validate** (lint + typecheck + tests)
8. **Propose the commit**

### Save Memory

9. **Save memory** (MANDATORY if FORGE project — never skip):
   ```bash
   forge-memory log "Quick-spec terminé : {DESCRIPTION}, {N} tests" --agent dev
   forge-memory consolidate --verbose
   forge-memory sync
   ```
