---
name: forge-resume
description: >
  FORGE Resume — Resumes an existing FORGE project by analyzing the current state and proposing next steps.
  Use when the user says "resume the project", "where did I leave off", "continue development",
  "what's the project status", "pick up where I left off", "what should I do next",
  "I'm back, what's next", or opens a FORGE project after a break and wants to know the current state.
  Do NOT use if FORGE is not initialized (use /forge-init first).
  Do NOT use for sprint metrics display only (use /forge-status).
  Usage: /forge-resume
---

# /forge-resume — Resume a FORGE Project

Resumes work on an existing FORGE project by analyzing the current state
and identifying the next action to take.

## Workflow

1. **Verify that FORGE is initialized**:
   - Read `.forge/config.yml` — if absent, suggest `/forge-init`
   - Read `CLAUDE.md` for project context

2. **Analyze the project state**:
   - Read `.forge/sprint-status.yaml` for sprint state
   - Read `docs/` for existing artifacts:
     - `docs/prd.md` exists? → Planning done
     - `docs/architecture.md` exists? → Architecture done
     - `docs/ux-design.md` exists? → UX done
     - `docs/stories/*.md` exist? → Stories decomposed
   - Identify stories by status:
     - `completed`: finished
     - `in_progress`: in progress (priority)
     - `pending`: to do
     - `blocked`: blocked (identify blockers)

   - Vector search for recent context:
     `forge-memory search "<project name> recent activity" --limit 3`
     → Load relevant history to better contextualize the resume

3. **Determine the next action**:

   **Case A — No artifacts**:
   → Suggest `/forge-plan` to start planning

   **Case B — PRD exists, no architecture**:
   → Suggest `/forge-architect`

   **Case C — Architecture exists, no stories**:
   → Suggest `/forge-stories`

   **Case D — Stories exist, some pending**:
   → Suggest `/forge-build STORY-XXX` for the next unblocked story

   **Case E — Story in_progress**:
   → Resume the current story with `/forge-build STORY-XXX`
   → Read the already written code and existing tests

   **Case F — All stories completed**:
   → Suggest `/forge-verify` for a global QA audit
   → Or `/forge-stories` to decompose new stories

4. **Display the resume report**:

   ```
   FORGE — Resuming project <name>
   ─────────────────────────────────
   Stack     : <type> / <language>
   Sprint    : #<id>
   Stories   : X completed / Y in_progress / Z pending / W blocked
   Last      : STORY-XXX (<status>) — <title>

   Artifacts:
     [OK] docs/prd.md
     [OK] docs/architecture.md
     [--] docs/ux-design.md (missing)
     [OK] docs/stories/ (N stories)

   Recommended next action:
     → /forge-build STORY-XXX — <story title>
   ```

5. **Propose available actions**:
   - Continue development (recommended action)
   - View full status (`/forge-status`)
   - Go back (re-plan, re-architect)
   - Add new stories

6. **Save memory** (ensures resume context persists for session continuity and activity tracking):
   ```bash
   forge-memory log "Projet repris : {X} completed, {Y} in_progress, {Z} pending, prochaine action: {NEXT_ACTION}" --agent resume
   forge-memory consolidate --verbose
   forge-memory sync
   ```

## Notes

- This skill is the entry point when opening an existing FORGE project
- It does not modify any files, it only analyzes and recommends
- Compatible with projects initialized manually or via `/forge-init`
- If sprint-status.yaml is missing but artifacts exist,
  the skill reconstructs the state from the existing files
