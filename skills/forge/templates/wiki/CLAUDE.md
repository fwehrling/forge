# FORGE Wiki -- Schema & Contract

This file is the **contract** for the knowledge wiki stored at `.forge/wiki/`. Read it at the start of every wiki operation. Conventions below are enforced by the `forge-wiki` agent.

## Philosophy

The wiki is a **compiled knowledge base** of the project. Sources (stories, bugs, commits, decisions) are ingested and **compiled into linked pages** -- not stored as raw dumps. Every page is meant to be read standalone AND explored via `[[wikilinks]]`.

Three layers:

1. **Raw layer** (`.forge/wiki/raw/`): untouched sources copied for provenance. Agent reads but rarely writes here.
2. **Wiki layer** (`.forge/wiki/wiki/`): compiled pages with wikilinks. Agent reads and writes.
3. **Contract layer** (this file): rules the agent follows.

## Directory Structure

```
.forge/wiki/
  CLAUDE.md            # this file (contract)
  index.md             # entry point, navigation hub
  log.md               # chronological ingestion journal
  raw/
    stories/           # copies of docs/stories/*.md at ingestion time
    bugs/              # debug session inputs
    notes/             # free-form notes the user added
  wiki/
    concepts/          # one page per component/feature
    stories/           # one page per story (STORY-XXX.md)
    bugs/              # one page per bug (BUG-XXX.md)
    decisions/         # ADR-XXX.md
    synthesis/         # answers to /query worth archiving
```

## Page Conventions

### Filename

- Lowercase with hyphens: `authentication.md`, not `Authentication.md` or `auth_system.md`
- IDs keep their prefix: `STORY-042.md`, `BUG-017.md`, `ADR-003.md`
- Synthesis slugs: `<short-topic>-<YYYY-MM-DD>.md` (e.g. `why-auth-middleware-2026-04-20.md`)

### Frontmatter

Every page MUST start with YAML frontmatter:

```yaml
---
type: concept | story | bug | decision | synthesis | note
title: Human-readable title
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [auth, backend, security]
---
```

For stories/bugs/decisions, add the ID:

```yaml
id: STORY-042
status: done | in-progress | archived
```

### Body Structure

#### Concept pages (`concepts/<name>.md`)

```markdown
# <Concept Name>

## Purpose
One paragraph: what this component does and why it exists.

## Related
- [[stories/STORY-042]] -- initial implementation
- [[stories/STORY-047]] -- auth extension
- [[bugs/BUG-017]] -- session token leak
- [[decisions/ADR-003]] -- chose JWT over sessions

## Notes
Free-form observations, constraints, known caveats.
```

#### Story pages (`stories/STORY-XXX.md`)

```markdown
# STORY-XXX -- <title>

## Summary
One-paragraph summary of what the story delivered.

## Concepts touched
- [[concepts/auth]]
- [[concepts/api]]

## QA verdict
PASS | CONCERNS | FAIL (with notes)

## Key decisions
Any non-obvious choice made during implementation.
```

#### Bug pages (`bugs/BUG-XXX.md`)

```markdown
# BUG-XXX -- <short description>

## Symptom
What the user saw.

## Root cause
Why it happened (result of forge-debug investigation).

## Fix
What changed and where.

## Concepts touched
- [[concepts/auth]]

## Prevention
What was added to prevent recurrence (tests, validation layers, etc.).
```

#### Decision pages (`decisions/ADR-XXX.md`)

```markdown
# ADR-XXX -- <decision title>

## Context
Why this decision was needed.

## Decision
What was chosen.

## Alternatives
Other options considered and why they were rejected.

## Consequences
Impact on the codebase and future work.

## Concepts touched
- [[concepts/auth]]
```

#### Synthesis pages (`synthesis/<slug>-<date>.md`)

```markdown
# <question as title>

**Asked**: YYYY-MM-DD

## Answer
Concise synthesis (5-15 lines).

## Sources
- [[stories/STORY-042]]
- [[concepts/auth]]
- [[decisions/ADR-003]]
```

## Wikilink Format

- Inline: `[[stories/STORY-042]]`, `[[concepts/auth]]`, `[[bugs/BUG-017]]`
- The path is relative to `.forge/wiki/wiki/`
- Never hardcode `./` or `../` -- always use `[[...]]` so Obsidian's graph view works
- Broken links flagged by `/forge wiki lint`

## Writing Rules

1. **Concise**: pages stay under 200 lines. Split if they grow too big.
2. **No dumps**: do not paste entire story bodies or commit diffs -- summarize.
3. **Link over repeat**: if info lives on another page, link to it.
4. **Idempotent updates**: re-ingesting the same source updates in place, never duplicates.
5. **Evergreen voice**: write as if the reader visits the page 6 months from now. Avoid "recently", "just now".
6. **Provenance**: every story/bug/ADR page links to its raw source in `.forge/wiki/raw/`.

## Ingestion Flow

When a source is ingested:

1. Copy raw source to `.forge/wiki/raw/<type>/` (if applicable).
2. Create or update the typed page (`stories/`, `bugs/`, `decisions/`).
3. For each concept mentioned, create or update the concept page and add a backlink.
4. Update `index.md` if a new top-level concept appears.
5. Append one line to `log.md`: `YYYY-MM-DDTHH:MM:SS | <source> | concepts: [[a]], [[b]] | pages touched: N`.

## Query Flow

When the user asks a question (`/forge wiki query "..."`):

1. Read `index.md` and grep the query keywords in `wiki/`.
2. Read the 3 best matches and their linked concepts (1 level deep).
3. Synthesize 5-15 lines with inline links to sources used.
4. If worth keeping, write to `synthesis/<slug>-<date>.md`.

## Lint Flow

`/forge wiki lint` checks:

- Broken wikilinks (target page missing)
- Orphan pages (no incoming links)
- Duplicate concepts (near-identical names)
- Contradictions (best-effort pattern match)

The agent reports findings but never auto-fixes.
