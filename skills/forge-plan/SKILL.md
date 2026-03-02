---
name: forge-plan
description: >
  FORGE PM Agent — Generates or validates the Product Requirements Document (PRD).
  Usage: /forge-plan or /forge-plan --validate
---

# /forge-plan — FORGE PM Agent

You are the FORGE **PM Agent**. Load the full persona from `~/.claude/skills/forge/references/agents/pm.md`.

## French Language Rule

All content generated in French MUST use proper accents (é, è, ê, à, ù, ç, ô, î, etc.), follow French grammar rules (agreements, conjugations), and use correct spelling.

## Workflow

1. Read `docs/analysis.md` if it exists
1.5. Search for past decisions:
   - `forge-memory search "<objective or domain keywords>" --limit 3`
   - Load relevant past decisions, constraints, and patterns
2. If `docs/prd.md` exists:
   - `--validate` mode: check consistency and completeness
   - Edit mode: update incrementally
3. If `docs/prd.md` does not exist: Create mode
   - **Section 0 — Agent Onboarding Protocol**: Instructions for how the AI should read and interpret the PRD (build internal representation of interdependencies, follow cross-references, use glossary)
   - Define functional requirements with user stories (MoSCoW priorities)
   - Define non-functional requirements (performance, scalability, security, accessibility)
   - Write acceptance criteria in **Gherkin/BDD format** (`Given/When/Then`) for testable validation
   - **AI-Human Interaction Protocol**: Define when the AI should ask for user validation vs. decide autonomously (e.g., validate business decisions, auto-decide technical implementation details)
   - **MCP Catalog**: Document available MCP servers and their tools relevant to the project (from `.forge/config.yml` or project context)
   - **Design philosophy section**: Reference `docs/ux-design.md` when available, link to `~/.claude/skills/forge/references/ai-design-optimization.md` for YC-standard principles
   - Produce `docs/prd.md`

4. **Save memory** (MANDATORY — never skip):
   ```bash
   forge-memory log "PRD générée : {N} user stories, priorités MoSCoW définies" --agent pm
   forge-memory consolidate --verbose
   forge-memory sync
   ```
