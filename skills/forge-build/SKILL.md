---
name: forge-build
description: >
  Dev Agent -- implements a user story with TDD (unit + functional tests).
  Requires a story file in docs/stories/.
paths:
  - ".forge/**"
  - "docs/stories/**"
---

# /forge-build — FORGE Dev Agent

You are the FORGE **Dev Agent**. Load the full persona from `~/.claude/skills/forge/references/agents/dev.md`.

## Workflow

1. **Identify the story**:
   - If an argument is provided (e.g., `STORY-003`), read `docs/stories/STORY-003-*.md`
   - Otherwise, read `.forge/sprint-status.yaml` and pick the next unblocked `pending` story

2. **Check for landing page requirement** (first story only):
   - If this is the FIRST story being built AND the project has no landing page yet:
   - Suggest building a **Landing Page (Y Combinator style)** as the first deliverable:
     - **Hero section**: Compelling headline (main benefit), sub-headline (context), primary CTA button, optional product visual
     - **Problem/Solution framing**: Concise articulation of the pain point and how the product solves it
     - **Benefits section**: 2-3 core benefits (not features), benefit-driven language, icons/visuals
     - **Social proof**: Testimonials, logos, "trusted by" (placeholders OK initially)
     - **Clear CTA repeat**: Prominent call-to-action at bottom
     - **Design**: Minimalist, mobile-first, fast-loading, clean semantic HTML
     - **SEO basics**: Title tags, meta descriptions, H1 structure, analytics ready
     - **Reference**: `~/.claude/skills/forge/references/ai-design-optimization.md` for YC-standard design patterns
   - This is a suggestion, not mandatory — the user decides

3. **Load context** (skip files already loaded in this conversation):
   - Read the full story file
   - Read `docs/architecture.md` (section 2.4 Design System) — skip if already loaded
   - Read `.forge/config.yml` section `design:` — skip if already loaded
   - `forge-memory search "<story title> <AC keywords>" --limit 3` — skip if similar search done

4. **Write unit tests** (TDD):
   - 1 test file per module/component in `tests/unit/<module>/`
   - Nominal, edge, and error cases

5. **Write functional tests**:
   - 1 test per acceptance criterion (AC-x) in `tests/functional/<feature>/`
   - Complete user flows

6. **Implement** the code to make all tests pass

7. **Validation gate** (all must pass — skipping this leads to QA failures downstream):

   ```
   [ ] All unit tests pass
   [ ] All functional tests pass (at least 1 per AC-x)
   [ ] Coverage >80% on new code
   [ ] No linting errors (`pnpm run lint`)
   [ ] No type errors (`pnpm run typecheck`)
   [ ] Non-regression: pre-existing tests are not broken
   ```

8. **Update** `.forge/sprint-status.yaml` (story status, test count)

9. **Save memory** (ensures continuity between sessions and feeds the vector index for future context retrieval):
   ```bash
   forge-memory log "{STORY_ID} terminée : {N} tests, couverture {X}%" --agent dev --story {STORY_ID}
   forge-memory consolidate --verbose
   forge-memory sync
   ```

10. **Report to user**:

    ```
    FORGE Dev — Build Complete
    ─────────────────────────────
    Story     : STORY-XXX — <title>
    Tests     : X unit + Y functional (all passing)
    Coverage  : XX%
    Lint/Type : clean

    → Launching /forge-verify STORY-XXX automatically...
    ```

11. **Auto-chain**: Immediately invoke `/forge-verify {STORY_ID}` — do NOT ask the user, launch it automatically. This ensures the build→verify→review pipeline flows without interruption.
