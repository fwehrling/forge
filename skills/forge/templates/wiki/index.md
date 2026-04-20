---
type: index
title: Wiki Home
created: {{DATE}}
updated: {{DATE}}
---

# {{PROJECT_NAME}} -- Knowledge Wiki

This wiki is the compiled knowledge base of the **{{PROJECT_NAME}}** project. Stories, bugs, architecture decisions, and component notes live here as linked pages.

## Navigation

- **[[concepts/]]** -- components and features of this project
- **[[stories/]]** -- user stories that shipped
- **[[bugs/]]** -- bugs investigated and fixed
- **[[decisions/]]** -- architecture decisions (ADRs)
- **[[synthesis/]]** -- archived answers to past queries

## Top-level concepts

(populated as the wiki grows)

## How to use

- **Search**: grep `.forge/wiki/wiki/` for keywords, or let the `forge-wiki` agent do it via `/forge wiki query "..."`.
- **Ask**: `/forge wiki query "pourquoi ce composant existe ?"` returns a synthesis citing sources.
- **Inspect**: `/forge wiki lint` reports broken links, orphans, and duplicates.
- **Manual save**: `/forge wiki save "<note>"` archives a free-form note.

## Anatomy

See `.forge/wiki/CLAUDE.md` for the schema contract -- naming, frontmatter, wikilink format, and writing rules.

## Auto-ingestion

The wiki is updated automatically when:

- A user story passes QA (via `forge-verify`)
- `/forge ship` pushes to main
- `forge-debug` resolves a bug
- You run `/forge wiki ingest` manually

Open this directory in Obsidian for graph view (optional -- everything works without it).
