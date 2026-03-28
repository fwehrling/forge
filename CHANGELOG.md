# Changelog

All notable changes to FORGE are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.6] - 2026-03-28

### Changed

- **README pipeline diagram**: replaced Mermaid flowchart with a clean SVG image (`assets/pipeline.svg`) -- no more interactive controls overlay, supports dark/light themes

## [1.7.5] - 2026-03-28

### Fixed

- **README pipeline table**: moved `/forge-review` from "Tools" to "Pipeline" section to reflect the canonical pipeline order (plan -> architect -> ux -> stories -> build -> verify -> review)
- **README changelog**: updated latest version reference from v1.7.3 to v1.7.4

## [1.7.4] - 2026-03-28

### Added

- **Pipeline order in router**: `forge/SKILL.md` now documents the canonical pipeline sequence (plan -> architect -> ux -> stories -> build -> verify -> review), visible even without `/forge-auto`

## [1.7.3] - 2026-03-28

### Fixed

- **install.sh updates Business Pack**: when Business Pack skills are already installed, `install.sh` now updates them alongside core skills. Previously only `/forge-update` handled this, leaving Business Pack skills outdated after reinstall

## [1.7.2] - 2026-03-28

### Fixed

- **Deprecated skill cleanup**: `install.sh` and `/forge-update` now remove skills that no longer exist in the repo (e.g., `forge-deploy`). Previously, deprecated skills remained orphaned in `~/.claude/skills/`

## [1.7.1] - 2026-03-28

### Fixed

- **install.sh summary**: added `-e` flag to `echo` in `print_summary()` for proper ANSI color rendering

## [1.7.0] - 2026-03-28

### Added

- **RTK integration**: `bash-interceptor.js` auto-detects [RTK](https://github.com/rtk-ai/rtk) (Rust Token Killer) for 60-90% output compression. Falls back to `token-saver.sh` if not installed
- **RTK install step**: `install.sh` now proposes RTK installation (step 6/7) with Homebrew or curl
- **`paths` frontmatter**: 25 skills use `paths: [".forge/**"]` so their descriptions are only loaded in FORGE projects -- zero token cost in non-FORGE projects
- **`disable-model-invocation`**: `forge-audit-skill` and `forge-loop` are hidden from auto-invocation (manual only via `/`)
- **Business Pack suggestion in install.sh**: first install now suggests the Business Pack if not present
- **Context Cache protocol**: 14 pipeline skills include "skip if already loaded" directives to avoid re-reading `docs/prd.md`, `docs/architecture.md`, and `MEMORY.md` across chained skills

### Changed

- **Skill descriptions reduced 61%**: all 32 descriptions shortened from ~9,200 to ~3,555 chars total (~120 chars avg vs ~290 before). Removed verbose "Use when:" lists, kept keywords natural
- **token-saver.sh improved**: replaced `eval` with `bash -c`, added `git add/commit/push/pull/fetch/checkout/merge/rebase` filters, improved `git log` compact format (hash + date + message), better test failure capture
- **bash-interceptor.js**: added git write commands to filtered set (add, commit, push, pull, fetch, checkout, merge, rebase)
- **Install steps**: 6 -> 7 steps (added RTK check)

### Removed

- **`forge-deploy`**: skill removed along with all references (router, auto, review, configuration, routing, packs.yaml, install.sh)

## [1.6.2] - 2026-03-26

### Changed

- **Non-interactive install**: `install.sh` now installs vector memory automatically without prompting. The interactive confirmation was removed -- vector memory is part of the standard install
- **`setup.sh --auto` flag**: `forge-memory/setup.sh` accepts `--auto` to skip the initial sync confirmation prompt. Interactive mode is preserved when the script is called standalone (without `--auto`)

## [1.6.1] - 2026-03-25

### Fixed

- **Hook infrastructure aligned with v1.6.0**: `forge-hooks-setup.sh` and `token-saver-setup.sh` now install the unified `bash-interceptor.js` instead of the deprecated `command-validator.js` + `output-filter.js`. Both scripts also clean up legacy hooks on update
- **UserPromptSubmit hook removed from install/update**: `forge-hooks-setup.sh` no longer installs `forge-auto-router.js` or the PreToolUse[Skill] notification hook -- these were removed in v1.6.0 but the scripts still installed them
- **Settings.json migration**: `forge-hooks-setup.sh` now removes legacy hook entries (UserPromptSubmit, PreToolUse[Skill], old Bash hooks) from `settings.json` during update
- **CLAUDE.md template cleaned**: Removed obsolete "Auto-Routing /forge" and "Skill Priority" sections from `templates/claude-md-forge-section.md` -- users upgrading via `/forge-update` get a clean CLAUDE.md automatically
- **Hook naming harmonized**: Renamed `forge-memory-stop.sh` to `forge-memory-sync.sh` across repo, README, and CHANGELOG for consistency with `settings.json`
- **`install.sh`**: Verification step and summary now reference the correct hooks (`bash-interceptor.js` instead of 3 separate files)
- **`forge-update/SKILL.md`**: Step 7 updated with current hook list
- **`forge-init/SKILL.md`**: Step 8 references `bash-interceptor.js` instead of `output-filter.js`
- **README rewritten**: Condensed from 893 to ~350 lines -- clearer value proposition, scannable structure, removed redundant sections

## [1.6.0] - 2026-03-25

### Changed

- **Router reduced 87%**: `forge/SKILL.md` cut from 514 lines (23 KB) to 75 lines (2.9 KB). Routing tables, dynamic creation template, and prompt injection defense moved to `references/routing.md` and `references/dynamic-creation.md`
- **All skill descriptions reduced 65%**: Average description size cut from ~630 chars to ~222 chars across all 32 FORGE skills. Removed "Do NOT use for..." clauses and "Usage:" suffixes -- disambiguation is handled by the router, not individual descriptions
- **References reduced 94%**: `ai-coding-optimization.md` (79 KB -> 4 KB) and `ai-design-optimization.md` (54 KB -> 4 KB) replaced with concise actionable guides
- **CLAUDE.md template reduced 94%**: Auto-routing section (63 lines) replaced with minimal 4-line FORGE section. Skill priority mapping and Agent Teams decision table removed (router handles this)

### Removed

- **UserPromptSubmit hook**: `forge-auto-router.js` removed -- eliminated the triple-routing pattern (hook -> router -> target skill) that added ~7,000 tokens per request. Claude Code's native skill matching via descriptions handles routing at zero additional cost
- **PreToolUse Skill hook**: "FORGE active" notification removed -- unnecessary token overhead on every skill invocation
- **Prompt injection defense section**: Removed from router SKILL.md -- Claude Code handles this natively

### Added

- **`references/routing.md`**: Extracted routing tables, intent classification, and disambiguation rules
- **`references/dynamic-creation.md`**: Extracted dynamic agent creation template and validation rules

### Fixed

- **Bash hooks merged**: `command-validator.js` and `output-filter.js` combined into single `bash-interceptor.js`, halving PreToolUse latency per Bash command

## [1.5.6] - 2026-03-22

### Fixed

- **CRITICAL: CLAUDE.md template missing auto-routing section**: The `Auto-Routing /forge` instructions were only in the maintainer's personal CLAUDE.md, not in the installed template. New users installing FORGE had the `UserPromptSubmit` hook active but Claude had no instructions to act on it -- `/forge` routing was silently broken for all new installs
- **CLAUDE.md template missing Business Pack section**: Added `FORGE Business Pack` description so users know about the optional pack and its agents

## [1.5.5] - 2026-03-22

### Fixed

- **README**: Corrected core skills count from 19 to 20 in routing domains table
- **README**: Added missing installation step 3 (configure `~/.claude/CLAUDE.md`), now lists all 6 steps
- **CHANGELOG**: Added missing release links for v1.5.3, v1.5.4, v1.5.5
- **`forge-update-check.sh`**: Replaced non-ASCII arrow (`->`) with ASCII `->` in update notification message
- **`forge-hooks-setup.sh`**: Added idempotency guard (`if [ ! -f ]`) to `statusline.sh` creation, matching all other hooks

## [1.5.4] - 2026-03-22

### Fixed

- **`/forge-update` SKILL.md**: Added missing `statusline.sh` to hooks list and updated PreToolUse[Skill] description to reflect `additionalContext` change

## [1.5.3] - 2026-03-22

### Added

- **FORGE status line**: Persistent `[Model] FORGE active | project-name` indicator in the Claude Code terminal bottom bar when working in a FORGE project (`.forge/` detected). Installed as `~/.claude/hooks/statusline.sh` and configured automatically via `statusLine` in `settings.json`
- **Visible skill notification**: PreToolUse[Skill] hook now uses `additionalContext` instead of `systemMessage`, making "FORGE active : skill-name" visible to the user in the conversation (previously only visible to the AI)

### Changed

- **`forge-hooks-setup.sh`**: Now installs `statusline.sh` (section 7) and patches `statusLine` config in `settings.json` (section 8). Hook count updated from 6 to 7
- **`install.sh`**: Verification step now checks `statusline.sh` alongside other hook files

## [1.5.2] - 2026-03-22

### Added

- **FORGE Hooks installer** (`forge-hooks-setup.sh`): New comprehensive setup script that installs all FORGE-specific hooks during `install.sh` and `/forge-update`. Hooks installed:
  - `forge-auto-router.js` -- UserPromptSubmit: routes user requests through `/forge` intelligent router
  - `forge-update-check.sh` -- SessionStart: checks for FORGE updates (1x per 24h, non-blocking)
  - `forge-memory-sync.sh` -- Stop: auto-syncs vector memory when session ends
  - `command-validator.js` -- PreToolUse[Bash]: blocks dangerous commands (rm -rf, DROP DATABASE, git push --force main, etc.)
  - `output-filter.js` + `token-saver.sh` -- PreToolUse[Bash]: token optimization (output filtering)
  - PreToolUse[Skill] notification: displays "FORGE active" in Claude Code window when a FORGE skill is invoked
- **FORGE skill notification**: Users now see a visual "FORGE active : skill-name" message in Claude Code whenever a FORGE skill is triggered

### Changed

- **`install.sh`**: Step 5 now runs `forge-hooks-setup.sh` (was `token-saver-setup.sh`), installing all FORGE hooks at once. Update-check hook removed from step 2 (deduplicated into step 5). Verification step now checks all 6 hook files individually
- **`/forge-update`**: Step 7 now runs `forge-hooks-setup.sh` to install/update all hooks during updates (was only updating `forge-update-check.sh`)
- **`/forge-init`**: SKILL.md updated to clarify that Token Saver is installed at init time, while all other FORGE hooks come from `install.sh` or `/forge-update`

## [1.5.1] - 2026-03-21

### Added

- **Prompt injection defense**: Comprehensive anti-injection system across the entire FORGE ecosystem:
  - Router: detection patterns, response protocol, and defense scope directive
  - Dynamic agent creation: name validation (`^[a-z0-9-]+$`) and content scan before writing
  - Memory system: "Memory Security" section treating stored content as potentially tainted
  - forge-audit-skill: self-protection against hostile skill files being audited
  - forge-review: awareness of injection in code comments
  - forge-analyze: external content warning for web research
  - Business Pack (seo, geo, marketing, business-strategy): external content warnings
  - security.md: documented 3-level defense and attack vector mitigation table
- **Token Saver improvements**: HOME fallback, error logging, git log regex fix, passthrough logging, settings path escaping, chmod validation

### Fixed

- **Memory fallback**: Skills no longer crash if `forge-memory` CLI is not installed. They fall back to direct Markdown reads of MEMORY.md and session files. Vector search is now optional, not a hard dependency
- **Stop hook**: Added `forge-memory-sync.sh` hook that runs `consolidate` + `sync` when sessions end, catching memory updates from skills that crashed before their END block

### Changed

- **Config via env vars**: `config.py` now reads `FORGE_VECTOR_WEIGHT`, `FORGE_FTS_WEIGHT`, `FORGE_SEARCH_THRESHOLD`, `FORGE_SEARCH_LIMIT`, `FORGE_CHUNK_SIZE`, `FORGE_CHUNK_OVERLAP` from environment variables with hardcoded defaults as fallback

### Removed

- **Agent-specific memory**: Removed `.forge/memory/agents/` directory and all references. Session logs already tag entries with `[agent_name]` and `(STORY-ID)`, making per-agent files redundant. Removed from: `memory.md`, `configuration.md`, `forge-init.sh`, `forge-memory/SKILL.md`, `sync.py`, `README.md`

## [1.5.0] - 2026-03-21

### Added

- **Business Pack**: 8 optional skills installable via `/forge-update --pack business`:
  - `forge-marketing` — Social media & content strategy (ex agent Maya)
  - `forge-copywriting` — Copywriting & conversion optimization (ex agent Theo)
  - `forge-seo` — SEO & analytics (ex agent Leo)
  - `forge-geo` — GEO/LLMO & AI search visibility (ex agent SEO-GEO)
  - `forge-legal` — E-commerce & auto-entrepreneur law (ex agent E-commerce Legal)
  - `forge-security-pro` — Deep security audit & OWASP hardening (ex agent Victor)
  - `forge-business-strategy` — Market research & business strategy (ex agent Clara)
  - `forge-strategy-panel` — Multi-expert strategy panel (ex agent Business Panel)
- **`/forge-debug`**: New core skill for systematic root cause investigation. 4-phase scientific method (investigate, analyze patterns, form hypothesis, implement). Includes defense-in-depth and condition-based waiting techniques. Chains to `/forge-quick-spec` once root cause is identified
- **`packs.yaml`**: Manifest file categorizing skills into `core` (24 skills) and `business` (8 skills) packs
- **`/forge-update --pack business`**: Updater now supports optional pack installation and auto-updates previously installed pack skills on regular updates

### Changed

- **`/forge` router**: Resolution Cascade replaces simple priority order — 5-step cascade (core skill -> Business Pack -> standalone -> suggest pack install -> dynamic agent creation) ensures FORGE always delivers
- **`/forge` router**: Business/marketing/SEO/legal/security routes now use Skill tool invocations instead of Task tool with subagent_type. Old custom agent references removed
- **`/forge` router**: `framework` domain renamed to `specialist` (handled via dynamic agent creation)
- **`/forge` router**: Adaptive routing — if a Business Pack skill is not installed, FORGE suggests installing the pack; if refused, creates a dynamic agent on the fly
- **`/forge-update`**: Step numbering updated (1-13), added pack installation step, auto-detection of previously installed pack skills, Business Pack suggestion for new users

### Removed

- **5 redundant skills**: `business-analysis`, `debug`, `oneshot`, `sqlite-database-expert`, `stripe-integration` — functionality covered by existing FORGE core skills
- **8 custom agents from `~/.claude/agents/`**: Migrated into Business Pack skills (maya-social-media, victor-security, theo-copywriter, clara-business-strategy, leo-seo-analytics, business-panel-experts, ecommerce-legal-expert, seo-geo-expert)
- **`angular-expert` and `nextjs-expert` agents**: Removed — Claude handles these frameworks natively, no dedicated agent needed

## [1.4.2] - 2026-03-19

### Fixed

- **French accents restored**: 7 occurrences of stripped accents in `/forge` SKILL.md (e->e, a->a, c->c encoding regression from v1.4.0)
- **Memory Protocol section restored**: Routing decision logging to forge-memory was accidentally removed
- **On Invocation Failure section restored**: Error handling for failed skill/agent invocations was accidentally removed
- **Router workflow restored to 6 steps**: Steps 2 (`.forge/` context check) and 5 (memory logging) were accidentally dropped, reducing workflow from 6 to 4 steps
- **README examples improved**: Router examples updated with more representative use cases (full pipeline, single story, quick fix)

## [1.4.0] - 2026-03-19

### Changed

- **`/forge` core skill**: Transformed from a documentary hub (230 lines listing commands) into an **intelligent router** (282 lines) that classifies user intent and automatically delegates to the right FORGE skill or custom agent. The user now types `/forge "anything"` and the router handles dispatch
- **Frontmatter description**: Rewritten with universal triggers covering dev, business, marketing, SEO, security, legal, and framework domains
- **Philosophy/Quick Start sections**: Replaced with a Router section defining core behavior — classify, select, invoke, never execute

### Added

- **Intent Classification system**: 4-dimension analysis (Domain, Action, Specificity, Scale) with 9 domain categories, 15 action verbs, 4 specificity levels, and 4 scale levels
- **Routing Table**: Complete dispatch table covering 6 target categories — Dev Pipeline (18 FORGE skills), Dev Tooling (4 skills), Business (Clara, Business Panel), Marketing (Maya, Theo, Leo, GEO Expert), Security (forge-audit vs Victor disambiguation), Legal (E-commerce Legal Expert), Framework (Angular Expert, Next.js Expert)
- **Invocation Protocol**: 3 mechanisms — Skill tool for FORGE skills, Task tool for custom agents, sequential chaining for 2-target requests (3+ delegates to forge-auto)
- **Dynamic Creation (professional-grade)**: Generates new agent files on-the-fly in `~/.claude/agents/` when no existing target matches. Created agents follow skill-creator best practices — full persona (name, expertise, frameworks), structured output templates, limits/boundaries, pushy description with trigger phrases, domain-appropriate color, and French language rules. Agents are invoked immediately and persist for future routing
- **Disambiguation Rules**: Decision table for ambiguous requests (security audit context detection, named agent routing, scope overflow to forge-auto)
- **Condensed Reference section**: Pipeline overview, tracks, and memory summary with links to detailed reference files

### Removed

- **Documentary content**: Agent Registry table, Agent Invocation Pattern, Scale-Adaptive Intelligence details, Workflows section, Autonomous Loops section, Persistent Memory section, Security Model section, MCP Integration section, Configuration section, full Reference Files listing — all moved to or already covered by `references/*.md`

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

[1.6.2]: https://github.com/fwehrling/forge/releases/tag/v1.6.2
[1.6.1]: https://github.com/fwehrling/forge/releases/tag/v1.6.1
[1.6.0]: https://github.com/fwehrling/forge/releases/tag/v1.6.0
[1.5.6]: https://github.com/fwehrling/forge/releases/tag/v1.5.6
[1.5.5]: https://github.com/fwehrling/forge/releases/tag/v1.5.5
[1.5.4]: https://github.com/fwehrling/forge/releases/tag/v1.5.4
[1.5.3]: https://github.com/fwehrling/forge/releases/tag/v1.5.3
[1.5.2]: https://github.com/fwehrling/forge/releases/tag/v1.5.2
[1.5.1]: https://github.com/fwehrling/forge/releases/tag/v1.5.1
[1.5.0]: https://github.com/fwehrling/forge/releases/tag/v1.5.0
[1.4.2]: https://github.com/fwehrling/forge/releases/tag/v1.4.2
[1.4.0]: https://github.com/fwehrling/forge/releases/tag/v1.4.0
[1.3.0]: https://github.com/fwehrling/forge/releases/tag/v1.3.0
[1.2.0]: https://github.com/fwehrling/forge/releases/tag/v1.2.0
[1.1.0]: https://github.com/fwehrling/forge/releases/tag/v1.1.0
[1.0.3]: https://github.com/fwehrling/forge/releases/tag/v1.0.3
[1.0.2]: https://github.com/fwehrling/forge/releases/tag/v1.0.2
[1.0.1]: https://github.com/fwehrling/forge/releases/tag/v1.0.1
[1.0.0]: https://github.com/fwehrling/forge/releases/tag/v1.0.0
