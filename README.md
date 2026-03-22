# FORGE

**Framework for Orchestrated Resilient Generative Engineering**

[![version](https://img.shields.io/badge/version-1.5.4-green)](https://github.com/fwehrling/forge/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey)](#prerequisites)
[![Skills](https://img.shields.io/badge/skills-24%20core%20%2B%208%20business-orange)](#commands)
[![Agents](https://img.shields.io/badge/agents-12%20pipeline%20%2B%20dynamic-purple)](#multi-agent-pipeline)
[![n8n](https://img.shields.io/badge/n8n-workflows-ff6d5a?logo=n8n)](https://n8n.io)
[![Token Saver](https://img.shields.io/badge/token%20saver-up%20to%20--97%25-brightgreen)](#token-saver)
[![Memory](https://img.shields.io/badge/memory-Markdown%20%2B%20Vector-yellow)](#memory-system)
[![GitHub stars](https://img.shields.io/github/stars/fwehrling/forge?style=flat&logo=github)](https://github.com/fwehrling/forge/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/fwehrling/forge?style=flat&logo=github)](https://github.com/fwehrling/forge/issues)

A multi-agent AI framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). One command — `/forge "anything"` — and the intelligent router classifies your intent and delegates to the right agent: dev pipeline, business strategy, marketing, SEO, security, legal, or framework expertise. Persistent memory, autonomous iteration, and built-in quality gates included.

```
/forge "Build a REST API with authentication"
```

That's it. FORGE classifies your intent, picks the right agent, and handles the rest.

---

## How It Works

`/forge` is the **single entry point**. Describe what you need in natural language, and the intelligent router classifies your intent, selects the best target (FORGE skill, custom agent, or dynamically created agent), and invokes it automatically.

```bash
/forge "build a REST API with auth"          # → routes to /forge-auto (full pipeline)
/forge "implement STORY-001"                 # → routes to /forge-build (single story)
/forge "fix the login bug"                   # → routes to /forge-quick-spec (quick track)
/forge "why is this crashing"                # → routes to /forge-debug (root cause investigation)
/forge "write a LinkedIn post"               # → routes to /forge-marketing (Business Pack)
/forge "OWASP audit of the project"          # → routes to /forge-audit
/forge "analyze SaaS competition"            # → routes to /forge-business-strategy (Business Pack)
/forge "plan and design payment system"      # → chains /forge-plan → /forge-architect
```

Under the hood, FORGE assigns specialized AI agents to each phase of software development. Each agent produces versioned artifacts that downstream agents consume, eliminating context loss between phases.

```mermaid
flowchart LR
    R["<b>Requirements</b><br/>Analyst → PM<br/><i>analysis.md · prd.md</i>"]
    D["<b>Design</b><br/>Architect → UX<br/><i>architecture.md · ux-design.md</i>"]
    DEV["<b>Development</b><br/>Scrum Master → Dev<br/><i>stories/*.md · src/ · tests/</i>"]
    Q["<b>Quality</b><br/>QA → DevOps<br/><i>certified · deployed</i>"]

    R ==> D ==> DEV ==> Q
```

Each agent is a lightweight Markdown persona loaded on demand from `~/.claude/skills/forge/references/agents/`.

### Routing Domains

The `/forge` router covers **6 domains** beyond development:

| Domain | Targets |
|--------|---------|
| **Dev pipeline** | 19 core skills (init, analyze, plan, architect, ux, stories, build, debug, verify, deploy...) |
| **Dev tooling** | status, resume, memory, update |
| **Business** | forge-business-strategy, forge-strategy-panel (Business Pack) |
| **Marketing** | forge-marketing, forge-copywriting, forge-seo, forge-geo (Business Pack) |
| **Security** | forge-security-pro (Business Pack) or /forge-audit (core pipeline) |
| **Legal** | forge-legal (Business Pack) |

If no existing target matches, the router follows a **Resolution Cascade**: check installed skills, suggest the Business Pack if relevant, or **create a new agent on-the-fly** and invoke it immediately. FORGE always delivers.

### Execution Modes

FORGE offers three ways to drive development (the router picks automatically, or you can be explicit):

```mermaid
flowchart TD
    F(["/forge 'your request'"])
    F -->|"Router classifies intent"| Q{{"Scale?"}}

    Q -->|"Full pipeline"| AUTO(["<b>/forge-auto</b>"])
    Q -->|"Parallel tasks"| TEAM(["<b>/forge-team</b>"])
    Q -->|"Single step"| SKILL(["<b>/forge-*</b>"])

    AUTO --> AD["Sequential pipeline<br/>analyze → plan → arch → ux → stories → build → verify → review<br/>Checkpoints: --no-pause · --pause-stories · --pause-each"]
    TEAM --> TD2["Parallel execution with real Claude Code instances<br/>3 patterns: pipeline · party · build<br/>Up to 4 Dev + 1 QA + 1 Reviewer simultaneously"]
    SKILL --> SD["Single skill or agent invoked directly"]
```

**Autopilot checkpoints** (`/forge-auto`):
- `--no-pause` — fully autonomous, no checkpoints
- `--pause-stories` — pause for approval after story decomposition (default)
- `--pause-each` — pause after every pipeline phase

**The router decides, or you can override:**
- `/forge "build this project from A to Z"` — routes to `/forge-auto`
- `/forge "build these stories in parallel"` — routes to `/forge-team`
- `/forge "implement STORY-001"` — routes to `/forge-build`
- `/forge "write a landing page copy"` — routes to `/forge-copywriting` (Business Pack)
- Direct command — `/forge-auto`, `/forge-build`, etc. still work for explicit control

---

## Features

### Multi-Agent Pipeline
12 specialized pipeline agents (Analyst, PM, Architect, UX, Scrum Master, Dev, QA, Quick QA, Reviewer, Orchestrator, DevOps, Security) that collaborate through artifacts. Plus a dedicated Debug skill for root cause investigation, and 8 optional Business Pack skills for marketing, SEO, legal, security, and strategy.

### Persistent Memory
Two-layer memory system (Markdown + optional vector search) that survives across sessions. FORGE always knows where it left off. Works without vector search (direct Markdown reads), enhanced with it. See [Memory System](#memory-system) for details.

```
.forge/memory/
  MEMORY.md              # Long-term project knowledge
  sessions/YYYY-MM-DD.md # Daily session logs (auto-generated, tagged by agent)
  index.sqlite           # Vector search index (auto-generated, optional)
```

### Autopilot Mode (`/forge-auto`)
Give FORGE an objective, and it drives the entire pipeline autonomously — choosing the right agent for each phase, running quality gates, and iterating until done.

### Manual Control (`/forge-*`)
Full manual control when you want it. Every step of the pipeline is a standalone command.

### Autonomous Loops (`/forge-loop`)
Secured iteration engine running **outside** Claude Code. Cost caps, circuit breakers, Docker sandbox, and git rollback. See [Autonomous Loops](#autonomous-loops) for details.

### Scale-Adaptive Intelligence
FORGE auto-detects project complexity and adjusts its approach:

| Track          | When                       | Agents Used            |
| -------------- | -------------------------- | ---------------------- |
| **Quick**      | Bug fix, hotfix (<1 day)   | Dev only               |
| **Standard**   | Feature, module (1-5 days) | PM, Architect, SM, Dev, QA |
| **Enterprise** | System, platform (5+ days) | All + Security + DevOps |

### Test-Driven Pipeline
Tests are integrated at every stage — not just verification. The SM specifies test cases, the Dev writes and runs them (TDD), and the QA audits and extends coverage.

### Agent Teams (`/forge-team`)
True parallel execution using real Claude Code instances (not subagents). Three patterns:

| Pattern      | Trigger                         | Description                                    |
| ------------ | ------------------------------- | ---------------------------------------------- |
| **Pipeline** | `/forge-team pipeline "goal"`   | Full pipeline with parallel story development  |
| **Build**    | `/forge-team build STORY-001 …` | Parallel story implementation + integrated QA  |
| **Party**    | `/forge-team party "topic"`     | Multi-perspective analysis with debate         |

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` env.

### Security Model
5-layer defense: input validation, sandbox isolation, credential management, audit/rollback, and human gates. Autonomous loops run in Docker sandboxes with network whitelisting.

**Prompt injection defense**: 3-level protection against injection from web content, code comments, third-party skills, and memory poisoning. The router detects injection patterns, flags them to the user, and never executes injected instructions. All skills that read external content (web research, code review, skill auditing) include explicit untrusted-content directives. Memory is treated as data, not commands.

### Token Saver

Shell commands like `git log`, `npm test`, or `cargo build` produce verbose output that wastes tokens. Token Saver intercepts known commands via a Claude Code PreToolUse hook, executes them through a filtering wrapper, and returns only the essential lines (errors, summaries, status changes).

Installed automatically by `/forge-init` and `install.sh`. Zero external dependencies (Node.js + Bash only).

**How it works:**

```mermaid
sequenceDiagram
    participant Claude
    participant Hook as output-filter.js<br/>(PreToolUse hook)
    participant Saver as token-saver.sh
    participant Shell as npm test

    Claude->>Hook: wants to run "npm test"
    Hook->>Hook: detects known command → rewrites
    Hook->>Saver: executes via wrapper
    Saver->>Shell: runs npm test
    Shell-->>Saver: 1025 lines / 52 KB
    Saver->>Saver: filters output
    Saver-->>Claude: 29 lines / 1 KB<br/>(PASS/FAIL per file + summary)
```

**Benchmarks** (real project — 696 commits, 713 Jest tests):

| Command | Before | After | Reduction |
|---------|--------|-------|-----------|
| `npm test` (713 tests passing) | 1025 lines / 52 KB | 29 lines / 1 KB | **-97%** |
| `git diff` (20 commits) | 11,268 lines / 420 KB | 201 lines / 7 KB | **-98%** |
| `git log -10` | 112 lines | 20 lines | **-82%** |
| `npm install` | 17 lines | 3 lines | **-76%** |

**What the AI still sees:**

| Scenario | Preserved information |
|----------|----------------------|
| Tests pass | PASS/FAIL per file, test count, duration |
| Tests fail | Failed file + error details (Expected/Received, stack trace, up to 60 lines) |
| `git diff` | Diff headers, hunk markers, changed lines (capped at 200 lines with truncation notice) |
| `git log` | Commit hash + commit message (no Author/Date/body) |
| `git status` | Branch, modified/added/deleted files, tracking info |
| Build errors | All error and warning lines preserved |

The AI can bypass the filter at any time by using a pipe (e.g., `git diff | cat`), since complex commands with `|`, `&&`, or `;` are passed through unfiltered.

**Covered commands:**

| Category | Commands |
|----------|----------|
| Git | `git status`, `git diff`, `git log` |
| Node.js | `npm test`, `npm install`, `npx jest`, `npx vitest` |
| pnpm | `pnpm test`, `pnpm install`, `pnpm add`, `pnpm run test` |
| Yarn | `yarn test`, `yarn install` |
| Bun | `bun test`, `bun install` |
| Python | `pip install`, `pytest`, `python -m pytest` |
| Go | `go test` |
| Rust | `cargo test`, `cargo build` |
| Docker | `docker build` |
| Make | `make`, `make test` |
| Java | `mvn test`, `mvn install`, `gradle test`, `gradle build` |
| .NET | `dotnet test`, `dotnet build` |
| Swift | `swift test`, `swift build` |
| TypeScript | `tsc` |

**Safety guarantees:**
- Passthrough by default — unknown commands are untouched
- Complex commands (pipes `|`, chains `&&`) are never filtered
- If filter output is empty, the original output is returned in full
- If the hook crashes, exit 0 (passthrough — fail open, never fail closed)
- Exit code of the original command is always preserved

**Files:**

```
~/.claude/hooks/
  output-filter.js        # PreToolUse[Bash] — detects and rewrites commands
  token-saver.sh          # Wrapper — executes command, filters output
  command-validator.js    # PreToolUse[Bash] — blocks dangerous commands
  forge-auto-router.js   # UserPromptSubmit — routes requests through /forge
  forge-update-check.sh  # SessionStart — FORGE update notifications (1x/24h)
  forge-memory-sync.sh   # Stop — auto-syncs vector memory on session end
  statusline.sh          # Status line — persistent FORGE indicator in terminal
```

---

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git
- macOS, Linux, or **Windows via [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)** (Git Bash is not supported)
- Python 3.9+ (optional — for [vector memory search](#vector-search-optional))
- Docker (optional — for sandbox isolation in autonomous loops)

---

## Installation

### Option A — Skills only (quick)

Copy the skills to your Claude Code configuration. Markdown memory works out of the box; vector search requires [additional setup](#vector-search-optional).

Using the [Skills CLI](https://github.com/anthropics/skills) (if available):

```bash
npx skills add fwehrling/forge -g --all
```

Or manually:

```bash
git clone https://github.com/fwehrling/forge.git /tmp/forge
cp -r /tmp/forge/skills/* ~/.claude/skills/
```

> **Note**: Option A installs skills only. It does **not** install FORGE hooks (auto-router, token-saver, update-check, memory-sync, command-validator, skill notifications, status line). Use [Option B](#option-b--full-install-recommended) for the complete setup.

### Option B — Full install (recommended)

The install script copies skills, checks your environment, and optionally sets up vector memory:

```bash
git clone https://github.com/fwehrling/forge.git /tmp/forge
bash /tmp/forge/install.sh
```

The installer will:
1. Detect your OS (macOS, Linux, WSL)
2. Copy all FORGE skills to `~/.claude/skills/`
3. Check for Python 3.9+ and offer to set up vector memory
4. Install all FORGE hooks (auto-router, update-check, memory-sync, command-validator, token-saver, skill notifications, status line)
5. Verify the installation and display a summary

### Initialize a project

```bash
# Inside your project with Claude Code
/forge-init
```

FORGE auto-detects your stack (language, framework, package manager) and generates:
- `.forge/config.yml` — project configuration
- `CLAUDE.md` — project conventions for Claude
- `.forge/memory/MEMORY.md` — persistent memory

### Build Something

```bash
# Just tell FORGE what you need — the router handles the rest
/forge "Implement user authentication with JWT"
/forge "Fix the login bug"
/forge "Write a LinkedIn post about our launch"
/forge "Security audit of the API"
/forge "Analyze the competitive landscape"

# Or use direct commands when you want explicit control
/forge-auto "Build the whole project"   # Full pipeline, autopilot
/forge-build STORY-001                  # Implement a specific story
/forge-verify STORY-001                 # QA audit + certification
/forge-quick-spec                       # Quick track: spec + implement
/forge-resume                           # Resume where you left off
```

---

## Updating

FORGE checks for updates automatically at session startup (once every 24 hours). If a new version is available, you'll see a non-blocking notification suggesting to run `/forge-update`.

### Auto-update (recommended)

```bash
# Inside Claude Code
/forge-update
```

This will:
1. Clone the latest version from GitHub
2. Compare installed skills with the new ones
3. Show a summary of changes (modified, new, removed)
4. Copy updated core skills to `~/.claude/skills/`
5. Auto-update previously installed Business Pack skills (if any)
6. Clean up temporary files

### Install the Business Pack (optional)

```bash
/forge-update --pack business
```

Installs 8 additional skills for marketing, SEO, legal, security, and business strategy. Once installed, they are auto-updated by `/forge-update`.

### Manual update

```bash
git clone https://github.com/fwehrling/forge.git /tmp/forge
bash /tmp/forge/install.sh
```

---

## Memory System

FORGE uses a two-layer Markdown-based memory system for cross-session continuity. Every FORGE **agent command** reads memory at start and writes updates at end. Vector search is optional -- FORGE works without it via direct Markdown reads, and is enhanced with it for large projects.

### How It Works

```mermaid
flowchart TD
    subgraph START ["START — Load context"]
        S1["forge-memory search (if installed)"]
        S2["OR read MEMORY.md + latest session (fallback)"]
        S1 --> S2
    end

    subgraph EXECUTE ["EXECUTE"]
        E1["Perform work"]
        E2["Track decisions"]
        E1 --> E2
    end

    subgraph END ["END — Save"]
        N1["forge-memory log (or manual append)"]
        N2["forge-memory consolidate"]
        N3["forge-memory sync"]
        N1 --> N2 --> N3
    end

    START --> EXECUTE --> END
```

Every agent skill enforces the END protocol. A Claude Code **Stop hook** (`forge-memory-stop.sh`) provides a safety net -- when a session ends, it automatically runs `consolidate` + `sync` for any FORGE project detected in the working directory. This catches memory updates from skills that crashed before completing their END block.

### Vector Search (optional)

Vector search adds semantic retrieval on top of the Markdown layer. It indexes all `.md` files into a local SQLite database using embeddings, enabling fuzzy context lookups.

**Setup** (requires Python 3.9+):

```bash
bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh
```

This creates an isolated venv, installs dependencies (`sentence-transformers`, `sqlite-vec`), downloads the embedding model (~80 MB), and adds the `forge-memory` CLI to your PATH via `~/.local/bin`.

```bash
# Usage (auto-detects project from CWD)
forge-memory sync --verbose                         # Index all .md files
forge-memory search "auth decisions" --pretty       # Hybrid vector + keyword search
forge-memory status                                 # Index statistics
forge-memory log "STORY-001 done" --agent dev       # Append to session log
forge-memory consolidate --verbose                  # Merge session logs into MEMORY.md
```

### Session Logging

FORGE agents automatically log their activity to daily session files. The `consolidate` command merges session entries into MEMORY.md, grouped by story.

```
.forge/memory/sessions/YYYY-MM-DD.md:
  - **14:32:10** [dev] (STORY-001) — Implemented auth module: 12 tests, 87% coverage
  - **15:10:45** [qa] (STORY-001) — QA PASS: all criteria validated
```

The sync scope includes both `.forge/memory/` and `docs/` (stories, architecture, PRD), so all project artifacts are searchable via vector search.

### With vs Without Vector Search

| | Without vector search | With vector search |
| --- | --- | --- |
| **Setup** | Nothing extra | Python 3.9+ and `setup.sh` |
| **Context retrieval** | Reads full Markdown files | Reads files + semantic search across all fragments |
| **Best for** | Small projects, few memory files | Large projects, extensive session history |
| **Files used** | `.md` only | `.md` + `index.sqlite` (auto-generated) |
| **Speed** | Instant (file reads) | Fast (local embeddings, no network) |
| **Precision** | Exact (you get the whole file) | Targeted (relevant chunks ranked by similarity) |

---

## Commands

### Entry Point

| Command | Description |
|---------|-------------|
| **`/forge "request"`** | **Intelligent router** — classifies intent and delegates to the right skill or agent. This is the recommended way to use FORGE. |

### Pipeline (also accessible via `/forge`)

| Command            | Agent     | Output                     | Description                          |
| ------------------ | --------- | -------------------------- | ------------------------------------ |
| `/forge-auto`      | All       | Full pipeline              | Autopilot mode (sequential)          |
| `/forge-team`      | All       | Full pipeline              | Parallel execution via Agent Teams   |
| `/forge-analyze`   | Analyst   | `docs/analysis.md`         | Domain research, requirements        |
| `/forge-plan`      | PM        | `docs/prd.md`              | Product requirements document        |
| `/forge-architect` | Architect | `docs/architecture.md`     | System architecture                  |
| `/forge-ux`        | UX        | `docs/ux-design.md`        | Wireframes, design system, a11y      |
| `/forge-stories`   | SM        | `docs/stories/*.md`        | Story decomposition with test specs  |
| `/forge-build`     | Dev       | Source code + tests         | Implementation (TDD)                 |
| `/forge-debug`     | Debug     | Root cause + handoff        | Systematic investigation (4 phases)  |
| `/forge-verify`    | QA        | Test report + verdict       | Quality audit and certification      |
| `/forge-deploy`    | DevOps    | Deployed application        | Staging + production deployment      |

### Orchestration & Tools (also accessible via `/forge`)

| Command                       | Description                                       |
| ----------------------------- | ------------------------------------------------- |
| `/forge-party "topic"`        | Multi-agent collaboration (2-3 in parallel)       |
| `/forge-loop "task"`          | Autonomous iteration loop with guardrails         |
| `/forge-quick-spec`           | Quick track: spec + implement directly            |
| `/forge-quick-test`           | Zero-config testing with auto framework detection |
| `/forge-review`               | Adversarial review of an artifact                 |
| `/forge-audit`                | Security audit: threat model, OWASP (Enterprise)  |
| `/forge-audit-skill <path>`   | Security audit of a third-party skill             |
| `/forge-memory`               | Vector memory: sync, search, status, log, consolidate |
| `/forge-init`                 | Initialize FORGE in a project                     |
| `/forge-resume`               | Resume work on an existing FORGE project          |
| `/forge-status`               | Sprint status, stories, metrics                   |
| `/forge-update`               | Update FORGE skills from latest release           |

### Business Pack (optional — install with `/forge-update --pack business`)

| Skill | Domain | Trigger examples |
|-------|--------|------------------|
| `/forge-business-strategy` | Business | "analyze competition", "pricing strategy", "market research" |
| `/forge-strategy-panel` | Business | "multi-expert debate", "strategic analysis", "should we pivot" |
| `/forge-marketing` | Marketing | "LinkedIn post", "content calendar", "social media strategy" |
| `/forge-copywriting` | Marketing | "landing page copy", "email funnel", "conversion optimization" |
| `/forge-seo` | SEO | "SEO audit", "keyword research", "Core Web Vitals" |
| `/forge-geo` | SEO | "AI search visibility", "GEO optimization", "Perplexity" |
| `/forge-security-pro` | Security | "OWASP review", "hardening" (outside FORGE pipeline) |
| `/forge-legal` | Legal | "CGV", "RGPD", "mentions légales", "auto-entrepreneur" |

---

## Architecture

### Project Structure

FORGE skills are installed globally in `~/.claude/skills/` (not inside the project). The project only contains the `.forge/` directory and generated artifacts:

```
your-project/
  .forge/
    config.yml              # FORGE configuration
    sprint-status.yaml      # Sprint tracking
    memory/                 # Persistent memory
      MEMORY.md             #   Project knowledge base
      sessions/             #   Daily session logs (tagged by agent + story)
      index.sqlite          #   Vector search index (auto-generated, optional)
  docs/                     # Generated artifacts (indexed by vector search)
    analysis.md             # Analyst output
    prd.md                  # PM output
    architecture.md         # Architect output
    ux-design.md            # UX output
    security.md             # Security audit output
    adrs/                   # Architecture Decision Records (Enterprise track)
    stories/                # SM output (stories with test specs)
  CLAUDE.md                 # Project conventions (auto-generated by /forge-init)

# Skills installation location (global):
~/.claude/skills/
  # Core skills (24 — installed by default)
  forge/                    # Intelligent Router + scripts + references
  forge-auto/               # Autopilot mode
  forge-analyze/            # Analyst agent
  forge-plan/               # PM agent
  forge-architect/          # Architect agent
  forge-ux/                 # UX agent
  forge-stories/            # SM agent
  forge-build/              # Dev agent
  forge-debug/              # Systematic root cause investigation
  forge-verify/             # QA agent
  forge-deploy/             # DevOps agent
  forge-audit/              # Security agent (Enterprise)
  forge-loop/               # Autonomous loop
  forge-team/               # Agent Teams parallel execution
  forge-party/              # Multi-agent orchestration
  forge-quick-spec/         # Quick track (cause known)
  forge-quick-test/         # Quick QA
  forge-review/             # Adversarial reviewer
  forge-audit-skill/        # Skill security auditor
  forge-memory/             # Vector memory diagnostic
  forge-init/               # Initialization skill
  forge-resume/             # Resume skill
  forge-status/             # Sprint status skill
  forge-update/             # Update skill

  # Business Pack (8 — optional, install with /forge-update --pack business)
  forge-marketing/          # Social media & content strategy
  forge-copywriting/        # Copywriting & conversion
  forge-seo/                # SEO & analytics
  forge-geo/                # GEO/LLMO & AI search
  forge-legal/              # E-commerce & auto-entrepreneur law
  forge-security-pro/       # Deep security audit & OWASP hardening
  forge-business-strategy/  # Market research & business strategy
  forge-strategy-panel/     # Multi-expert strategy panel
```

---

## Autonomous Loops

`/forge-loop` is fundamentally different from other FORGE commands. It is a **bash script** (`forge-loop.sh`) that runs **outside** Claude Code, orchestrating multiple isolated Claude sessions with hardware-enforced security guardrails.

### How It Differs

| | `/forge-auto` | `/forge-team` | `/forge-loop` |
| --- | --- | --- | --- |
| **Runs** | Inside a Claude Code session | Inside a Claude Code session | Outside — bash script launching Claude |
| **Scope** | Full project pipeline | Parallel story development | Single task, iterated until done |
| **Sessions** | 1 session, many agents | 1 session, many teammates | N sessions, 1 per iteration |
| **Sandbox** | No | No | Docker container (optional) |
| **Cost cap** | No | No | Hard $ limit per loop |
| **Circuit breakers** | No | No | 3 types (errors, no progress, same output) |
| **Git rollback** | No | No | Tag checkpoint per iteration |
| **Best for** | "Build this project A to Z" | "Build these stories in parallel" | "Fix this overnight, don't burn $50" |

### Architecture

```mermaid
flowchart TD
    START["/forge-loop 'task'"] --> GEN["1. Generate PROMPT.md\n(task + state)"]
    GEN --> CKPT["2. Git checkpoint\n(tag forge-ckpt-iter-N)"]
    CKPT --> LAUNCH["3. Launch fresh Claude session\nclaude --print -p PROMPT.md"]
    LAUNCH --> CAPTURE["4. Capture output"]
    CAPTURE --> ANALYZE{"5. Analyze output"}

    ANALYZE -->|"FORGE_COMPLETE"| DONE["Done ✓"]
    ANALYZE -->|"FORGE_BLOCKED"| BLOCKED["Blocked ✗"]
    ANALYZE -->|"Circuit breaker\n(errors / no progress / same output)"| BREAK["Break ✗"]
    ANALYZE -->|"Cost cap exceeded"| BREAK
    ANALYZE -->|"Continue"| GEN

    subgraph guards ["Security Guardrails"]
        G1["Cost cap ($)"]
        G2["Circuit breakers (3 types)"]
        G3["Rate limit"]
        G4["Docker sandbox"]
        G5["Git rollback"]
    end

    style guards fill:none,stroke:#ff6b6b,stroke-dasharray: 5 5
```

### Modes

| Mode | Behavior | Human interaction | Best for |
| --- | --- | --- | --- |
| **AFK** | Fully autonomous | None | Overnight runs, batch tasks |
| **HITL** | Semi-autonomous | Confirmation every 5 iterations | Default — safe balance |
| **Pair** | Collaborative | Continuous feedback, small commits | Active development, learning |

### Security Guardrails

| Guardrail | What it does | Default |
| --- | --- | --- |
| **Cost cap** | Stops when estimated spend exceeds threshold (fixed rate per iteration, not actual API billing) | $10.00 |
| **Max iterations** | Hard limit on loop count | 30 |
| **Consecutive errors** | Stops after N consecutive failures | 3 |
| **No progress** | Stops if no `git diff` for N iterations | 5 |
| **Same output** | Stops if output hash repeats N times | 3 |
| **Rate limit** | Max iterations per hour | 60 |
| **Docker sandbox** | Isolated container, read-only docs, no network | Enabled |
| **Git checkpoints** | Tag before each iteration, rollback on failure | Last 5 kept |

### Usage

```bash
# Basic — iterate on a task with default guardrails
/forge-loop "Fix all failing tests in the auth module"

# With a story for context
/forge-loop "Implement STORY-003" --story docs/stories/STORY-003-auth.md

# Overnight run — fully autonomous, sandboxed
/forge-loop "Add unit tests to all services" \
  --mode afk --max-iterations 50 --cost-cap 25.00 --sandbox docker

# Pair programming — small commits, continuous feedback
/forge-loop "Refactor database layer to use repositories" --mode pair

# Rate-limited batch
/forge-loop "Migrate callbacks to async/await" \
  --mode afk --rate-limit 30 --sandbox docker
```

### Rollback

```bash
# List available checkpoints
forge-loop.sh checkpoint-list

# Restore a specific checkpoint
forge-loop.sh rollback --story forge-ckpt-iter-5
```

### When To Use It

You rarely need to call `/forge-loop` directly:

- **`/forge-auto` calls it automatically** when a story fails QA 3 consecutive times — it escalates to `/forge-loop` with the failure summary, which iterates with guardrails until tests pass
- **Use it manually** for long-running tasks where you want hard cost/safety limits — overnight refactoring, batch test writing, or any task where "run until done but don't spend more than $X" matters
- **Don't use it** for normal pipeline work — `/forge-auto`, `/forge-team`, or manual `/forge-build` are better suited

### State Files

Each loop maintains its state for continuity and post-mortem analysis:

```
.forge-state/
  state.json      # Current state (iteration, errors, mode, status)
  history.jsonl   # Complete event history
  fix_plan.md     # Task checklist (updated by each iteration)
```

---

## Configuration

Run `/forge-init` to generate the full config. Key sections:

```yaml
# .forge/config.yml (excerpt — /forge-init generates the complete file)
project:
  name: "my-project"
  type: auto-detect    # web-app | api | library | cli | mobile
  language: auto-detect
  scale: auto-detect   # quick | standard | enterprise

loop:
  max_iterations: 30
  cost_cap_usd: 10.00
  timeout_minutes: 60
  sandbox:
    enabled: true
    provider: docker   # docker | local | none

memory:
  enabled: true
  auto_save: true
  session_logs: true
  vector_search:
    enabled: false     # requires Python 3.9+ setup
    model: "all-MiniLM-L6-v2"
    auto_sync: true
  # Tunable via env vars: FORGE_VECTOR_WEIGHT, FORGE_FTS_WEIGHT,
  # FORGE_SEARCH_THRESHOLD, FORGE_SEARCH_LIMIT, FORGE_CHUNK_SIZE

security:
  audit_skills: true
  sandbox_loops: true
  credential_store: env

deploy:
  provider: ""
  staging_url: ""
  production_url: ""
  require_approval: true

# Also generated by /forge-init (not shown):
# mcp:    — MCP server integration endpoints
# n8n:    — n8n workflow webhooks and credentials
```

---

## Key Differentiators

What FORGE adds on top of using Claude Code directly:

- **Single entry point** — `/forge "anything"` classifies intent and routes to the right skill or agent automatically
- **Multi-agent pipeline** — Specialized agents per phase (PM, Architect, Dev, Debug, QA...) with artifact handoff
- **Beyond code** — Optional Business Pack adds marketing, SEO, security, legal, and strategy skills
- **Resolution Cascade** — Core skill -> Business Pack -> standalone -> dynamic agent creation. FORGE always delivers, never says "I can't"
- **Persistent memory** — Two-layer system (Markdown + optional vector search) that survives across sessions
- **Autonomous iteration** — Long-running loops with cost caps, circuit breakers, and sandbox isolation
- **Scale-adaptive intelligence** — Auto-detects project complexity and adjusts the pipeline depth
- **Integrated test strategy** — Tests specified by SM, written by Dev (TDD), audited by QA at every stage
- **Security guardrails** — 5-layer defense for autonomous execution + 3-level prompt injection protection across all skills
- **Parallel execution** — Agent Teams for true multi-instance parallel development
- **Token optimization** — Output filtering hooks reduce shell output by up to 97%

---

## Philosophy

FORGE is built on these principles:

1. **Agents are disposable, artifacts are permanent** — Agents produce Markdown artifacts that persist. Context is never lost between sessions.

2. **Memory over repetition** — The persistent memory system means FORGE never asks the same questions twice and always knows where it left off.

3. **Security by default** — Autonomous execution requires guardrails. Cost caps, sandboxing, circuit breakers, and human gates are built in, not bolted on.

4. **One command to rule them all** — `/forge "anything"` is the universal entry point. The router classifies, selects, and delegates. Direct `/forge-*` commands remain available for explicit control.

5. **Tests are first-class** — Every story includes test specifications. The Dev writes tests before code (TDD). The QA audits and extends. No story is done without passing tests.

---

## Acknowledgments

FORGE synthesizes concepts from several pioneering approaches to AI-driven development:

- **Multi-agent agile methodologies** for artifact-driven workflows and scale-adaptive planning
- **Autonomous iteration patterns** for loop architecture and exit detection
- **Claude Code Skills** for the native integration architecture
- **Persistent memory patterns** for cross-session continuity
- **n8n** for workflow automation concepts

---

## Changelog

### v1.5.4

- **`/forge-update` doc fix**: Added missing `statusline.sh` to hooks list

### v1.5.3

**FORGE Visual Identity** -- Persistent status line and visible skill notifications:

- **Status line**: `[Model] FORGE active | project-name` displayed persistently in the terminal bottom bar when in a FORGE project
- **Visible skill notification**: "FORGE active : skill-name" now visible to the user in the conversation (was only visible to the AI)
- **Auto-installed**: Status line and notifications set up automatically by `install.sh` and `/forge-update`

### v1.5.2

**FORGE Hooks** -- Complete hook infrastructure installed automatically:

- **`forge-hooks-setup.sh`**: New installer script deploys all FORGE hooks during `install.sh` and `/forge-update`
- **Hooks installed**: auto-router, update-check, memory-sync, command-validator, token-saver, skill notifications
- **Skill notification**: "FORGE active : skill-name" displayed in Claude Code when a FORGE skill is invoked
- **Install/update streamlined**: All hooks managed in one place, idempotent and safe to re-run

### v1.5.1

**Security & Reliability** -- Prompt injection defense, memory improvements, and Token Saver fixes:

- **Prompt injection defense**: 3-level protection across all skills (router detection, per-skill external content warnings, memory security)
- **Memory fallback**: Skills no longer crash if `forge-memory` CLI is not installed (direct Markdown reads as fallback)
- **Stop hook**: `forge-memory-stop.sh` catches memory updates from crashed sessions
- **Token Saver fixes**: HOME fallback, error logging, regex fix, path escaping, chmod validation
- **Config via env vars**: Memory search config tunable via `FORGE_VECTOR_WEIGHT`, `FORGE_SEARCH_THRESHOLD`, etc.
- **Cleanup**: Removed unused agent-specific memory (`.forge/memory/agents/`)

### v1.5.0

**Business Pack & Debug Agent** — Modular architecture with optional skill packs:

- **Business Pack**: 8 new optional skills (forge-marketing, forge-copywriting, forge-seo, forge-geo, forge-legal, forge-security-pro, forge-business-strategy, forge-strategy-panel) installable via `/forge-update --pack business`
- **`/forge-debug`**: New core skill for systematic root cause investigation (4-phase scientific method), chains to `/forge-quick-spec` for implementation
- **Resolution Cascade**: Router now follows a 5-step cascade (core -> Business Pack -> standalone -> suggest install -> dynamic creation) ensuring FORGE always delivers
- **`/forge-update --pack`**: Updater now supports optional pack installation and auto-updates previously installed packs
- **`packs.yaml`**: New manifest file categorizing skills into core and business packs
- **Cleanup**: Removed redundant skills (business-analysis, debug, oneshot, sqlite-database-expert, stripe-integration), migrated 8 custom agents into Business Pack skills

### v1.4.2

**Patch** — Fix regressions from v1.4.0: restore French accents, Memory Protocol, On Invocation Failure, full 6-step router workflow, improved README examples.

### v1.4.0

**Intelligent Router** — `/forge` transformed from a documentary hub into a universal entry point:

- **Router behavior**: `/forge` now classifies user intent (domain, action, specificity, scale) and automatically delegates to the right FORGE skill or custom agent — never executes tasks itself
- **Intent Classification**: 4-dimension analysis with domain categories (dev-pipeline, dev-tooling, business, marketing, seo, security, legal, specialist, unknown)
- **Complete Routing Table**: Covers all core FORGE skills + Business Pack skills + dynamic agent creation
- **Invocation Protocol**: Skill tool for all FORGE skills, Agent tool for dynamic creation, sequential chaining (max 2 targets, then forge-auto)
- **Dynamic Agent Creation**: Generates new agents on-the-fly in `~/.claude/agents/` when no existing target matches
- **Disambiguation Rules**: Context-aware routing (e.g., "security audit" routes to forge-audit in FORGE projects, forge-security-pro otherwise)

### v1.3.0

**Skill triggering & quality overhaul** — All 23 skill descriptions rewritten for reliable automatic triggering:

- **Descriptions**: Every skill now includes natural language trigger phrases, negative routing cases ("Do NOT use for X, use /forge-Y"), and pipeline positioning. Disambiguation matrix resolves all confusing skill pairs
- **French Language Rule**: Removed from 22 satellite skills — kept only in hub. Language is a user preference, not a per-skill concern
- **Output templates**: 15 skills now include concrete ASCII report examples (previously only `/forge-resume` had one)
- **Memory blocks**: "MANDATORY — never skip" replaced with WHY explanations across all agent skills
- **Step numbering**: Fixed all non-standard numbering (1.5, 2.5, 5b/5c, double-2) to sequential integers
- **Expanded skills**: `/forge-review` (35→65 lines with severity classification), `/forge-party` (perspectives table + synthesis format), `/forge-verify` (UI details moved to QA persona ref)
- **`/forge-auto`**: IF/ELSE pseudo-code converted to imperative style

### v1.2.0

**Modular architecture** — Refactored core skill for faster loading and maintainability:

- **`/forge` core skill**: Externalized detailed sections into 6 modular reference files (`workflows.md`, `memory.md`, `security.md`, `loops.md`, `configuration.md`, `mcp-integration.md`), reducing main SKILL.md from ~800 to ~130 lines
- **`/forge-audit-skill`**, **`/forge-init`**, **`/forge-review`**: Standardized usage syntax (`<param>` → `[param]`)

### v1.1.0

**Enriched skills** — Integrated best practices from structured development methodology research:

- **`/forge-analyze`**: Added structured idea intake (pre-analysis questionnaire) and concept validation & synthesis section (personas, USPs, positioning statement, MoSCoW matrix, success metrics). Full market research framework: SWOT, Porter's 5 Forces, TAM/SAM/SOM, competitive landscape, go-to-market strategies.
- **`/forge-plan`**: PRD now includes Agent Onboarding Protocol (Section 0), Gherkin/BDD acceptance criteria, AI-Human Interaction Protocol, MCP Catalog, and design philosophy section.
- **`/forge-build`**: First-story landing page suggestion (Y Combinator style) — hero section, problem/solution framing, social proof, SEO basics.
- **`/forge-ux`**: Structured design system template with exact specifications — colors (HEX), typography (type scale), spacing (base unit + scale), components (buttons/forms/cards/modals/nav/tables/alerts), responsive breakpoints, dark mode, animations. Reference to `ai-design-optimization.md`.
- **`/forge-verify`**: Pragmatic verification checks — link integrity, browser console audit, navigation testing, interactive elements, visual consistency, performance spot-check.
- **`/forge-quick-spec`**: Dual-track workflow — Bug Fix Track (root cause analysis, impact assessment, regression-first TDD, rollback plan) and Small Change Track.

**New reference documents:**

- `forge/references/ai-coding-optimization.md` — AI-friendly code patterns, documentation strategies, agent optimization (DeLP, AOP)
- `forge/references/ai-design-optimization.md` — YC-standard design guide, Tailwind CSS patterns, React component best practices, accessibility

---

## License

MIT License. See [LICENSE](LICENSE).

---

*Built for Claude Code. Designed for ambitious projects.*
