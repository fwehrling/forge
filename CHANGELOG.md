# Changelog

All notable changes to FORGE are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-03-08

### Changed

- **All 23 skill descriptions**: Rewritten with natural language trigger phrases ("Use when the user says..."), negative routing cases ("Do NOT use for... use /forge-X instead"), and pipeline context. Descriptions grew from 2-3 lines to 6-8 lines each, dramatically improving automatic skill triggering accuracy and disambiguation between similar skills (e.g., `/forge-quick-spec` vs `/forge-build`, `/forge-verify` vs `/forge-quick-test`, `/forge-party` vs `/forge-team party`)
- **French Language Rule**: Removed from 22 satellite skills — kept only in `/forge` (hub skill). Users configure language preferences in their `~/.claude/CLAUDE.md`, not per-skill
- **Step numbering**: Fixed non-standard numbering (1.5, 2.5, 5b, 5c) across `/forge-build`, `/forge-plan`, `/forge-status`, `/forge-update`, `/forge-verify` — all now use sequential integer numbering
- **Memory save blocks**: Replaced "MANDATORY — never skip" with explanations of WHY memory matters (e.g., "ensures QA verdicts persist for trend analysis and regression tracking") across all 14 agent skills
- **`/forge-review`**: Expanded from 35 to ~65 lines — added artifact-type-specific review lenses (code vs PRD vs architecture vs stories), severity classification (CRITICAL/WARNING/INFO), and structured report template with `file:line` references
- **`/forge-party`**: Expanded workflow — added available perspectives table, structured brief instructions for subagents, and synthesis report format template
- **`/forge-verify`**: Moved overly specific UI checks (hamburger menus, hover states, dropdowns) to QA persona reference; kept high-level pragmatic checks inline
- **`/forge-auto`**: Converted pseudo-code IF/ELSE block to imperative bullet-point style for better LLM consumption

### Added

- **Output format templates**: Added concrete ASCII report examples to 15 skills (`forge-build`, `forge-verify`, `forge-plan`, `forge-architect`, `forge-stories`, `forge-review`, `forge-deploy`, `forge-analyze`, `forge-ux`, `forge-audit`, `forge-loop`, `forge-quick-spec`, `forge-quick-test`, `forge-update`, `forge-audit-skill`). Previously only `forge-resume` had one
- **`/forge-memory`**: Added output examples for `status` and `search --pretty` commands
- **`/forge-party`**: Added available perspectives table (Architect, PM, Security, Dev, QA, Reviewer) with best-for guidance
- **`/forge-status`**: Added full sprint status table template with story breakdown, metrics, blockers, and backlog section

## [1.2.0] - 2026-03-05

### Changed

- **`/forge` core skill**: Refactored SKILL.md — externalized detailed sections into modular reference files (`references/workflows.md`, `references/memory.md`, `references/security.md`, `references/loops.md`, `references/configuration.md`, `references/mcp-integration.md`), reducing main skill from ~800 to ~130 lines for faster loading
- **`/forge-audit-skill`**, **`/forge-init`**, **`/forge-review`**: Standardized usage syntax from `<param>` to `[param]` (bracket convention for optional parameters)
- **`/forge` SKILL.md**: Condensed Scale-Adaptive Intelligence section, simplified Agent Registry headers, streamlined pipeline diagram

## [1.1.0] - 2026-03-02

### Added

- **`/forge-analyze`**: Structured idea intake (pre-analysis questionnaire) and concept validation & synthesis section (personas, USPs, positioning, MoSCoW, success metrics). Full market research framework: SWOT, Porter's 5 Forces, TAM/SAM/SOM, competitive landscape, go-to-market strategies
- **`/forge-plan`**: Agent Onboarding Protocol (Section 0), Gherkin/BDD acceptance criteria, AI-Human Interaction Protocol, MCP Catalog, design philosophy section
- **`/forge-build`**: First-story landing page suggestion (Y Combinator style) with hero, problem/solution, social proof, SEO basics
- **`/forge-ux`**: Structured design system template (colors HEX, typography scale, spacing, components, responsive breakpoints, dark mode, animations). Reference to `ai-design-optimization.md`
- **`/forge-verify`**: Pragmatic verification checks (link integrity, browser console audit, navigation testing, interactive elements, visual consistency, performance spot-check)
- **`/forge-quick-spec`**: Dual-track workflow — Bug Fix Track (root cause analysis, impact assessment, regression-first TDD, rollback plan) and Small Change Track
- `forge/references/ai-coding-optimization.md` — AI-friendly code patterns, documentation strategies, agent optimization
- `forge/references/ai-design-optimization.md` — YC-standard design guide, Tailwind CSS patterns, accessibility

## [1.0.3] - 2026-02-27

### Added

- Managed FORGE section in `~/.claude/CLAUDE.md` with `<!-- FORGE:BEGIN -->` / `<!-- FORGE:END -->` markers
- `templates/claude-md-forge-section.md` as single source of truth for FORGE config block
- `scripts/inject-claude-md.sh` for injection/update with automatic backup and user confirmation
- New install step [3/6] to configure `~/.claude/CLAUDE.md` during installation
- Step 5c in `/forge-update` to detect and propose FORGE section updates

## [1.0.2] - 2026-02-27

### Changed

- `/forge-auto` now runs `/forge-verify` then `/forge-review` after each story build (was only verify)
- `/forge-team` pipeline and build patterns now spawn a dedicated Reviewer teammate alongside QA
- Task dependency chain per story: Dev → QA (`/forge-verify`) → Review (`/forge-review`)
- QA teammate prompt aligned with `/forge-verify` workflow (structured audit, verdicts, memory log)
- Review feedback loop: critical issues trigger fix → re-verify → re-review (max 2 cycles)
- Team size updated to 4 Dev + 1 QA + 1 Reviewer

## [1.0.1] - 2026-02-23

### Fixed

- Suppress harmless HF/transformers warnings (`position_ids`, `unauthenticated HF Hub`) in vector memory

### Added

- shields.io badges in README (version, license, platform, skills, agents, n8n, token saver, memory, GitHub stars/issues)

## [1.0.0] - 2026-02-23

### Added

- Core FORGE framework (`/forge` main skill) with comprehensive reference document
- 12 specialized agent personas in `skills/forge/references/agents/`
- 23 skills covering the full development lifecycle:
  - Pipeline: `/forge-analyze`, `/forge-plan`, `/forge-architect`, `/forge-ux`, `/forge-stories`, `/forge-build`, `/forge-verify`, `/forge-deploy`
  - Orchestration: `/forge-auto` (autopilot), `/forge-team` (Agent Teams), `/forge-party` (multi-agent debate), `/forge-loop` (autonomous iteration)
  - Tools: `/forge-quick-spec`, `/forge-quick-test`, `/forge-review`, `/forge-audit`, `/forge-audit-skill`, `/forge-memory`, `/forge-init`, `/forge-resume`, `/forge-status`, `/forge-update`
- Persistent memory system (Markdown-based, two-layer: long-term + session)
- Vector memory search: SQLite + `all-MiniLM-L6-v2` embeddings, hybrid retrieval (70% vector + 30% FTS5 BM25)
- `forge-memory` CLI: sync, search, log, consolidate, status, reset
- Autonomous loop runner (`forge-loop.sh`) with cost caps, circuit breakers, rate limiting, sandbox isolation, and rollback checkpoints
- Token Saver: output filtering hooks to reduce shell output token consumption
- Cross-platform installer (`install.sh`) with OS detection (macOS, Linux, WSL)
- Update check hook (`forge-update-check.sh`) with 24h cache TTL
- Skill security auditor (`audit-skill.py`)
- Scale-adaptive intelligence (Quick / Standard / Enterprise tracks)
- Test-driven pipeline (SM specifies, Dev writes TDD, QA audits)
- 5-layer security model (input validation, sandbox, credentials, audit/rollback, human gates)
- ADR support in `/forge-architect` (Enterprise track)
- Three execution modes: Manual, Autopilot (with checkpoint flags), Agent Teams
- `CONTRIBUTING.md` with skill creation guide and testing procedures
- n8n workflow integration patterns (conceptual)
- MCP server integration patterns (conceptual)

[1.3.0]: https://github.com/fwehrling/forge/releases/tag/v1.3.0
[1.2.0]: https://github.com/fwehrling/forge/releases/tag/v1.2.0
[1.1.0]: https://github.com/fwehrling/forge/releases/tag/v1.1.0
[1.0.3]: https://github.com/fwehrling/forge/releases/tag/v1.0.3
[1.0.2]: https://github.com/fwehrling/forge/releases/tag/v1.0.2
[1.0.1]: https://github.com/fwehrling/forge/releases/tag/v1.0.1
[1.0.0]: https://github.com/fwehrling/forge/releases/tag/v1.0.0
