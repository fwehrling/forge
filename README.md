# FORGE

**Framework for Orchestrated Resilient Generative Engineering**

[![version](https://img.shields.io/badge/version-1.14.1-green)](https://github.com/fwehrling/forge/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey)](#prerequisites)
[![Skills](https://img.shields.io/badge/skills-27%20core%20%2B%208%20business-orange)](#commands)

> **Stop prompting. Start shipping.**
> FORGE turns Claude Code into a team of AI agents that plan, build, test, review, and deploy your project -- while you focus on decisions that matter.

```
/forge "Build a SaaS with auth, payments, and a dashboard"
```

One command. FORGE breaks it into requirements, architecture, stories, code, and tests. Each phase has a specialized agent. Artifacts flow from one to the next. Nothing gets lost.

---

## 30-Second Demo

```bash
# Install (one time)
git clone https://github.com/fwehrling/forge.git /tmp/forge && bash /tmp/forge/install.sh

# In your project
/forge init                                    # Detects your stack, creates .forge/
/forge "Build a REST API with JWT auth"        # Full pipeline with HITL quality gates
```

That's it. FORGE classifies your intent, selects the right flow (CREATE, FEATURE, DEBUG, IMPROVE, SECURE, or BUSINESS), and orchestrates every agent automatically. You validate at quality gates.

Want to resume where you left off? Just type `/forge` -- memory picks up exactly where you stopped.

---

## What Makes FORGE Different

### AI Agents That Actually Collaborate

1 hub orchestrator plus 26 specialized agents -- 8 pipeline (Analyst, PM, Architect, UX, Scrum Master, Dev, QA, Reviewer), 4 orchestration (Autopilot, Teams, Party, Loop), and 14 utility agents (Debug, Audit, Init, Think, Permissions, Wiki, etc.) -- that produce versioned Markdown artifacts. Each agent reads what the previous one wrote -- no context loss between phases.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/pipeline.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/pipeline.svg">
    <img alt="FORGE Pipeline: Requirements -> Design -> Development -> Quality" src="assets/pipeline.svg" width="700">
  </picture>
</p>

### Memory That Persists

FORGE remembers everything across sessions. Two-layer system: Markdown files for reliability, optional vector search for large projects.

```
.forge/memory/
  MEMORY.md              # Long-term project knowledge
  agents/{agent}.md      # Agent-specific memories
  sessions/YYYY-MM-DD.md # Daily session logs (tagged by agent)
  index.sqlite           # Vector search index (optional)
```

### Knowledge Wiki (Obsidian-compatible)

Every FORGE project gets a `.forge/wiki/` vault bootstrapped by `/forge init` -- a linked Markdown knowledge base inspired by Karpathy's 3-layer wiki (raw sources -> compiled concepts -> schema contract). Stories, bugs, and decisions are ingested automatically at pivotal events:

| Trigger | What gets ingested |
|---------|-------------------|
| Story QA PASS (`forge-verify`) | Story compiled into `wiki/stories/`, touched concepts updated |
| `/forge ship` after push to main | Commit logged, concept pages refreshed |
| `forge-debug` fix confirmed | `wiki/bugs/BUG-XXX.md` with root cause + fix |
| Session start | Hub reads last 20 lines of `log.md` + recent syntheses (anti-compaction) |

Manual commands: `/forge wiki ingest <source>`, `/forge wiki query "..."`, `/forge wiki lint`, `/forge wiki save "<note>"`.

The vault is versioned in Git, works without Obsidian installed (Claude reads/writes plain `.md`), and coexists with `forge-memory` -- wiki is the compiled project knowledge, memory is operational preferences.

### Built-In Token Optimization

Shell output wastes tokens. FORGE intercepts verbose commands and compresses them automatically. With [RTK](https://github.com/rtk-ai/rtk) (optional, proposed at install):

| Command | Typical savings |
|---------|----------------|
| `npm test` / `pytest` | **90-97%** (keeps pass/fail summary, drops verbose output) |
| `git diff` / `git log` | **85-98%** (keeps meaningful changes, drops noise) |
| `git status/add/commit/push` | **80-92%** (1-2 lines instead of verbose output) |

Zero config. RTK provides 60-90% compression on 50+ commands. Falls back to a generated `token-saver.sh` hook if RTK is not installed.

Hub-only architecture means zero token cost from satellite agents in the system prompt -- only the hub description is loaded per turn. Satellites are loaded on demand via `Read()`.

### Compressed Output (Slim/Caveman)

Installed automatically via `install.sh` or `update.sh`. A `SessionStart` hook activates compressed French output at every session -- shorter responses, no filler words, no articles, fragments OK. Three levels:

| Level | Style |
|-------|-------|
| **lite** (default) | No filler. Full sentences, professional tone |
| **full** | Articles dropped, fragments OK, short synonyms |
| **ultra** | Abbreviations (BDD/auth/config/req), arrows for causality (X -> Y) |

Switch level: `/forge slim lite|full|ultra`. Disable: `stop slim` or `mode normal`. Automatically switches to polished French for deliverables (PRD, architecture docs, etc.).

### Beyond Code

Optional **Business Pack** adds 8 skills for the rest of your business:

| Skill | What it does |
|-------|-------------|
| forge-business-strategy | Market research, TAM/SAM/SOM, pricing, PMF |
| forge-strategy-panel | Multi-expert debate (Porter, Christensen, Drucker...) |
| forge-marketing | Social media strategy, content calendars |
| forge-copywriting | Landing pages, email funnels, conversion |
| forge-seo | Technical SEO, Core Web Vitals, keywords |
| forge-geo | AI search visibility (ChatGPT, Perplexity, Gemini) |
| forge-security-pro | Deep OWASP audit, hardening |
| forge-legal | RGPD, CGV, auto-entrepreneur (French law) |

Install with: `/forge update --pack business`

---

## Flow-Based Architecture

One entry point: `/forge`. It classifies your intent and runs the right flow.

| Flow | Triggers | Pipeline |
|------|----------|----------|
| **CREATE** | "build a SaaS", "new MVP" | analyze -> plan -> architect -> ux -> stories -> build cycles |
| **FEATURE** | "add feature X" | plan -> stories -> build cycles |
| **DEBUG** | "bug", "why is this failing" | debug -> quick-spec -> verify -> review |
| **IMPROVE** | "refactor", "optimize" | review (audit) -> HITL -> fixes -> verify |
| **SECURE** | "security audit", "OWASP" | audit -> HITL -> fixes -> re-audit |
| **BUSINESS** | "marketing", "SEO", "legal" | strategy -> execution agents |

**Build cycles** include HITL quality gates: after QA + code review, you choose which findings to fix (Critical only, Critical+Warning, All, or Skip).

**Parallel execution**: `/forge team build STORY-001 STORY-002` uses Agent Teams for simultaneous story building.

**Autonomous loops**: `/forge loop` runs with cost caps, circuit breakers, configurable sandbox (Docker, local, or none), and git rollback.

---

## All Agents

Everything goes through `/forge`. The hub loads the right agent on demand.

### Pipeline Agents

| Agent | Role | Output |
|-------|------|--------|
| forge-analyze | Analyst | `docs/analysis.md` |
| forge-plan | PM | `docs/prd.md` |
| forge-architect | Architect | `docs/architecture.md` |
| forge-ux | UX Designer | `docs/ux-design.md` |
| forge-stories | Scrum Master | `docs/stories/*.md` |
| forge-build | Developer | Source + tests (TDD) |
| forge-verify | QA | Verdict (PASS/FAIL) |
| forge-review | Reviewer | Adversarial code review |

### Orchestration

| Agent | Role |
|-------|------|
| forge-auto | Full autopilot (sequential, `--no-pause`) |
| forge-team | Parallel execution via Agent Teams |
| forge-party | Multi-perspective debate (2-3 subagents) |
| forge-loop | Autonomous iteration with guardrails |

### Tools

| Command | Purpose |
|---------|---------|
| `/forge debug` | Systematic root cause investigation |
| `/forge quick-spec` | Bug fix or small change (skip PRD) |
| `/forge quick-test` | Run tests (auto-detects framework) |
| `/forge audit` | Security audit (threat model, OWASP) |
| `/forge audit-skill` | Audit a third-party skill |
| `/forge think` | Deep reasoning before implementation |
| `/forge permissions` | Permission/RBAC refactoring |
| `/forge memory` | Vector memory diagnostics |
| `/forge init` | Initialize FORGE in a project |
| `/forge resume` | Resume where you left off |
| `/forge status` | Sprint dashboard |
| `/forge slim` | Compressed output mode (auto-activated via hook, 3 levels) |
| `/forge wiki <mode>` | Knowledge wiki -- ingest/query/lint/save on `.forge/wiki/` |
| `/forge update` | Update FORGE skills |

---

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git
- macOS, Linux, or Windows via WSL (Windows Subsystem for Linux)
- Python 3.9+ (optional -- for vector memory)
- [RTK](https://github.com/rtk-ai/rtk) (optional -- for 60-90% token compression, proposed at install)

### Quick Install

**macOS / Linux / WSL:**
```bash
git clone https://github.com/fwehrling/forge.git /tmp/forge
bash /tmp/forge/install.sh            # Interactive (prompts for RTK, status line, etc.)
bash /tmp/forge/install.sh -y         # Non-interactive (accept all defaults)
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/fwehrling/forge.git $env:TEMP\forge
powershell -ExecutionPolicy Bypass -File $env:TEMP\forge\install.ps1
```

> `install.ps1` detects WSL automatically. If WSL is missing, it offers to install it (requires admin + reboot), then runs the FORGE installer inside WSL.

The installer copies the hub to `~/.claude/skills/forge/`, satellites to `~/.forge/skills/`, configures hooks, and sets up vector memory automatically. Then in your project:

```bash
/forge init
```

### Updating

From Claude Code:
```bash
/forge update                    # Core skills
/forge update --pack business    # + Business Pack
```

From terminal (without Claude Code):
```bash
bash /tmp/forge/update.sh                    # Core skills
bash /tmp/forge/update.sh --pack business    # + Business Pack
bash /tmp/forge/update.sh -y                 # Accept all prompts
```

FORGE checks for updates automatically at session startup (1x/24h).

---

## Project Structure

```
your-project/
  .forge/
    config.yml           # Project configuration
    sprint-status.yaml   # Sprint tracking
    flow-state.yaml      # Active flow state (CREATE, FEATURE, DEBUG...)
    memory/              # Persistent memory (Markdown + optional vector)
    wiki/                # Obsidian-compatible knowledge vault (concepts, stories, bugs, decisions)
  docs/                  # Generated artifacts (PRD, architecture, stories...)
  CLAUDE.md              # Project conventions (auto-generated)

~/.claude/
  skills/forge/          # Hub only (1 skill registered in Claude Code)
  hooks/                 # Token optimization, memory sync, update checks

~/.forge/
  skills/forge-*/        # 26 satellite agents (loaded on demand by the hub)
```

**Hub-only architecture**: Only the FORGE hub is registered in Claude Code's skill system. Satellite agents are invisible to the system prompt and loaded on demand via `Read()`.

---

## HITL Quality Gates

After every build -> verify -> review cycle, FORGE stops and asks:

```
FORGE -- Quality Gate
  3 CRITICAL / 5 WARNING / 8 INFO

  [C]     Critical only
  [CW]    Critical + Warning
  [ALL]   Fix everything
  [SKIP]  Accept as-is
  [1,3,5] Pick specific findings
```

Your choice. FORGE learns your preferences across sessions.

---

## Security

5-layer defense for autonomous execution: input validation, sandbox isolation, credential management, audit/rollback, and human gates.

- Autonomous loops support Docker sandbox isolation (configurable: docker, local, or none)
- Dangerous commands blocked at the hook level (`rm -rf /`, `DROP DATABASE`, `git push --force main`...)
- Prompt injection protection across all skills that read external content
- Cost caps and circuit breakers prevent runaway spending

---

## Philosophy

1. **Artifacts over agents** -- Agents are disposable. The Markdown artifacts they produce persist forever.
2. **Memory over repetition** -- FORGE never asks the same question twice.
3. **Tests are first-class** -- Every story has test specs. Dev writes TDD. QA audits coverage.
4. **Security by default** -- Guardrails are built in, not bolted on.
5. **One command** -- `/forge "goal"` starts the full pipeline. HITL gates keep you in control without micromanaging.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

**Latest -- v1.14.1**: statusline now tracks satellites loaded via `Read()`. Since v1.11.0 the hub loads forge-* satellites by reading their `SKILL.md` directly instead of calling `Skill()`, which silently broke the active-satellite indicator in the status line. A new `PreToolUse[Read]` hook + `read` action in `forge-skill-tracker.sh` restore the indicator for both loading paths. Propagates via `install.sh` and `/forge update`.

**v1.13.0**: wiki auto-ingest on every session. The `forge-memory-sync` Stop hook now captures commits and uncommitted files after every Claude response and queues them in `.forge/wiki/pending-ingest.yaml`; the hub drains the queue at the next session start via `forge-wiki` (new `pending:` source type). Every operation on a FORGE project contributes to the Obsidian-compatible knowledge base, whether `/forge` was invoked or not.

**v1.12.6**: `forge-verify` no longer invents transient story statuses like `fix-applied`. The QA satellite now writes only the canonical values (`pending` | `in_progress` | `blocked` | `completed`), keeping `/forge status`, `/forge resume`, and the hub flow state in sync.

**v1.12.5**: legacy slash command migration -- every user-facing `/forge-xxx` reference is now `/forge xxx` to match the hub-only architecture. SKILL.md titles, reference docs, install/update scripts, hook messages, `CLAUDE.md` and `CONTRIBUTING.md` templates all aligned. Historical CHANGELOG entries, file paths, and internal skill IDs preserved.

**v1.12.4**: `/forge update` scope cleanup -- removed the wiki retrofit side effect and the `--full` flag. Framework updates (hub, satellites, hooks) and project initialization (`.forge/`, wiki, memory) are now strictly separated. Legacy projects missing `.forge/wiki/` must run `/forge init` explicitly.

**v1.12.3**: `forge-init.sh` idempotency fix -- `.forge/config.yml` and `.forge/memory/MEMORY.md` are now preserved on re-run instead of being overwritten, protecting project history (decisions, session logs) when the script executes a second time.

**v1.12.2**: `/forge init` now retrofits `.forge/wiki/` on legacy projects already initialized without the vault -- makes init symmetrical with `/forge update` for the wiki retrofit path.

**v1.12.1**: README fix -- correct the "specialized agents" count (1 hub + 26 satellites, not 27) and mark `lite` as the default forge-slim level (aligning with the v1.11.7 behavior change).

**v1.12.0**: Obsidian-compatible knowledge wiki -- new `forge-wiki` satellite maintains `.forge/wiki/` vault with automatic ingestion at story QA PASS, `/forge ship`, and forge-debug handoff. Four modes (ingest/query/lint/save), Karpathy 3-layer architecture, versioned in Git, works with or without Obsidian. Lazy retrofit for legacy projects via `/forge init`.

**v1.11.8**: remove RTK native Read/Grep/Glob hook -- bypass pattern cost more tokens than the compression saved. Bash RTK hook (60-90% dev ops savings) stays active. `update.sh` auto-cleans the legacy hook.

**v1.11.7**: RTK anti-bypass inline notice in deny payload and forge-slim default set to lite.

**v1.11.6**: full codebase QA audit -- standardize closing statements across 33 satellites, fix script inconsistencies, shorten frontmatter descriptions, add forge-resume to hub.

**v1.11.5**: fix forge-init memory CLI install step and correct forge-slim satellite path for hub-only architecture.

**v1.11.4**: document Slim/Caveman compressed output mode in README -- auto-activated via hook, 3 levels, document mode for deliverables.

**v1.11.3**: README factual accuracy audit -- correct agent counts, add /forge prefix to examples, replace unverified metrics with typical ranges, clarify configurable Docker sandbox.

**v1.11.2**: ASCII encoding fix -- replace decorative Unicode with ASCII across all files, fix forge-init satellite path, correct README skill counts.

**v1.11.1**: RTK anti-bypass -- strengthened CLAUDE.md instructions to prevent Claude from working around RTK token compression.

**v1.11.0**: hub-only architecture -- satellites move to ~/.forge/skills/ (significant token savings per turn), flow-based orchestration (CREATE/FEATURE/DEBUG/IMPROVE/SECURE/BUSINESS), HITL quality gates, persistent flow-state for cross-session resume.

**v1.10.0**: forge-slim -- output token compression (~70% savings) with auto-activation via SessionStart hook, three intensity levels, and document mode for deliverables.

**v1.9.13**: statusline burn rate indicator -- red triangle warns when token usage exceeds expected 20%/hour rate (5% tolerance).

**v1.9.12**: add install.ps1 for Windows -- auto-detects WSL, offers to install it if missing, then runs the FORGE installer inside WSL.

**v1.7.10**: standalone `update.sh` script, fix memory setup banner.

**v1.7.9**: streamline 19 skill prompts (-240 lines), add router disambiguation table, add `.gitignore`.

**v1.7.8**: fix VERSION file not updated since v1.7.3.

**v1.7.7**: quick-spec now suggests verify + review as next steps.

**v1.7.6**: replace Mermaid diagram with clean SVG pipeline, move `/forge-review` to pipeline section.

**v1.7.5**: move `/forge-review` to pipeline section in README.

**v1.7.4**: pipeline order documented in forge router.

**v1.7.3**: install.sh updates Business Pack if already installed.

**v1.7.0**: RTK integration (60-90% output compression), `paths` frontmatter (skills load only in FORGE projects), descriptions reduced 61%, context cache, `forge-deploy` removed.

**v1.6.x**: Non-interactive install, hook infrastructure aligned, token optimization (-72%).

**v1.5.0**: Business Pack (8 skills), Debug agent, Resolution Cascade.

---

## License

MIT. See [LICENSE](LICENSE).

---

*Built for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Designed for ambitious projects.*
