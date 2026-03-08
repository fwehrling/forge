---
name: forge-status
description: >
  FORGE Sprint Status — Displays the current sprint status with stories, metrics, and progress.
  Use when the user says "show sprint status", "how is the sprint going", "what stories are done",
  "project progress", "which story is next", "sprint metrics", "what's blocked",
  or wants a quick overview of the current sprint without resuming development.
  Reads .forge/sprint-status.yaml — requires a FORGE project with stories defined.
  Do NOT use to resume development (use /forge-resume which analyzes state and proposes actions).
  Do NOT use for detailed story inspection (read docs/stories/ directly).
  Usage: /forge-status
---

# /forge-status — FORGE Sprint Status

Displays the current sprint status by reading `.forge/sprint-status.yaml`.

## Workflow

1. **Load context**:
   - Read `.forge/memory/MEMORY.md` for project context
   - Read the latest session from `.forge/memory/sessions/` for continuity

2. **Read sprint data**: Parse `.forge/sprint-status.yaml`

3. **Display summary table**:

   ```
   FORGE Sprint Status — <project name>
   ──────────────────────────────────────
   Sprint    : #<id>
   Stories   : X completed / Y in_progress / Z pending / W blocked

   | Story       | Status      | QA      | Review  | Assignee |
   |-------------|-------------|---------|---------|----------|
   | STORY-001   | completed   | PASS    | CLEAN   | dev      |
   | STORY-002   | in_progress | —       | —       | dev      |
   | STORY-003   | pending     | —       | —       | —        |
   | STORY-004   | blocked     | —       | —       | —        |

   Metrics:
     Tests    : XX pass / Y fail
     Coverage : XX%
     Velocity : X pts/sprint

   Blockers:
     - STORY-004 blocked by STORY-002

   Backlog (not in sprint):
     - STORY-010 — <title>
     - STORY-011 — <title>
   ```

4. **Identify next story**: First unblocked `pending` story

5. **Suggest next action**: `/forge-build STORY-XXX`

6. **Backlog section**: List all story files in `docs/stories/` and compare with stories in the sprint. Display stories NOT in the current sprint as "Backlog" with their ID and title (read from the story file's front matter or first heading). This gives visibility on upcoming work outside the sprint.
