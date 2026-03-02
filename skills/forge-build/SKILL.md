---
name: forge-build
description: >
  FORGE Dev Agent — Implements a story with unit + functional tests.
  Usage: /forge-build or /forge-build STORY-XXX
---

# /forge-build — FORGE Dev Agent

You are the FORGE **Dev Agent**. Load the full persona from `~/.claude/skills/forge/references/agents/dev.md`.

## French Language Rule

All content generated in French MUST use proper accents (é, è, ê, à, ù, ç, ô, î, etc.), follow French grammar rules (agreements, conjugations), and use correct spelling.

## Workflow

1. **Identify the story**:
   - If an argument is provided (e.g., `STORY-003`), read `docs/stories/STORY-003-*.md`
   - Otherwise, read `.forge/sprint-status.yaml` and pick the next unblocked `pending` story

1.5. **First story? Check for landing page requirement**:
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

2. **Load context**:
   - Read the full story file
   - Read `docs/architecture.md` (section 2.4 Design System)
   - Read `.forge/config.yml` section `design:`

2.5. **Contextual search**:
   - `forge-memory search "<story title> <AC keywords>" --limit 3`
   - Load relevant past decisions, patterns, and blockers as additional context

3. **Write unit tests** (TDD):
   - 1 test file per module/component in `tests/unit/<module>/`
   - Nominal, edge, and error cases

4. **Write functional tests**:
   - 1 test per acceptance criterion (AC-x) in `tests/functional/<feature>/`
   - Complete user flows

5. **Implement** the code to make all tests pass

6. **Validation gate** (MANDATORY before completion):

   ```
   [ ] All unit tests pass
   [ ] All functional tests pass (at least 1 per AC-x)
   [ ] Coverage >80% on new code
   [ ] No linting errors (`pnpm run lint`)
   [ ] No type errors (`pnpm run typecheck`)
   [ ] Non-regression: pre-existing tests are not broken
   ```

7. **Update** `.forge/sprint-status.yaml` (story status, test count)

8. **Save memory** (MANDATORY — never skip):
   ```bash
   forge-memory log "{STORY_ID} terminée : {N} tests, couverture {X}%" --agent dev --story {STORY_ID}
   forge-memory consolidate --verbose
   forge-memory sync
   ```

9. **Inform** the user of the result and suggest running `/forge-verify`
