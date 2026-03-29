# FORGE

**Framework for Orchestrated Resilient Generative Engineering**

[![version](https://img.shields.io/badge/version-1.7.21-green)](https://github.com/fwehrling/forge/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey)](#prerequisites)
[![Skills](https://img.shields.io/badge/skills-23%20core%20%2B%208%20business-orange)](#commands)

> **Stop prompting. Start shipping.**
> FORGE turns Claude Code into a team of AI agents that plan, build, test, review, and deploy your project -- while you focus on decisions that matter.

```
"Build a SaaS with auth, payments, and a dashboard"
```

One sentence. FORGE breaks it into requirements, architecture, stories, code, and tests. Each phase has a specialized agent. Artifacts flow from one to the next. Nothing gets lost.

---

## 30-Second Demo

```bash
# Install (one time)
git clone https://github.com/fwehrling/forge.git /tmp/forge && bash /tmp/forge/install.sh

# In your project
/forge-init                                    # Detects your stack, creates .forge/
/forge-auto "Build a REST API with JWT auth"   # Full pipeline, autopilot
```

That's it. FORGE handles the rest: requirements, architecture, stories, TDD implementation, and QA.

Want more control? Every step is a standalone command:

```bash
/forge-plan           # Write the PRD
/forge-architect      # Design the system
/forge-stories        # Break into stories
/forge-build STORY-001  # Implement with TDD
/forge-verify STORY-001 # QA audit
```

---

## What Makes FORGE Different

### AI Agents That Actually Collaborate

11 specialized agents (Analyst, PM, Architect, UX, Scrum Master, Dev, Debug, QA, Reviewer, Orchestrator, Security) that produce versioned Markdown artifacts. Each agent reads what the previous one wrote -- no context loss between phases.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/pipeline.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/pipeline.svg">
    <img alt="FORGE Pipeline: Requirements → Design → Development → Quality" src="assets/pipeline.svg" width="700">
  </picture>
</p>

### Memory That Persists

FORGE remembers everything across sessions. Two-layer system: Markdown files for reliability, optional vector search for large projects.

```
.forge/memory/
  MEMORY.md              # Long-term project knowledge
  sessions/YYYY-MM-DD.md # Daily session logs (tagged by agent)
  index.sqlite           # Vector search index (optional)
```

### Built-In Token Optimization

Shell output wastes tokens. FORGE intercepts verbose commands and compresses them automatically. With [RTK](https://github.com/rtk-ai/rtk) (optional, proposed at install):

| Command | Before | After | Savings |
|---------|--------|-------|---------|
| `npm test` (713 tests) | 52 KB | 1 KB | **-97%** |
| `git diff` (20 commits) | 420 KB | 7 KB | **-98%** |
| `git status/add/commit/push` | verbose | 1-2 lines | **-92%** |

Zero config. RTK provides 60-90% compression on 50+ commands. Falls back to built-in `token-saver.sh` if RTK is not installed.

Skills use `paths` frontmatter to load only in FORGE projects -- zero token cost in non-FORGE sessions.

### Beyond Code

Optional **Business Pack** adds 8 skills for the rest of your business:

| Skill | What it does |
|-------|-------------|
| `/forge-business-strategy` | Market research, TAM/SAM/SOM, pricing, PMF |
| `/forge-strategy-panel` | Multi-expert debate (Porter, Christensen, Drucker...) |
| `/forge-marketing` | Social media strategy, content calendars |
| `/forge-copywriting` | Landing pages, email funnels, conversion |
| `/forge-seo` | Technical SEO, Core Web Vitals, keywords |
| `/forge-geo` | AI search visibility (ChatGPT, Perplexity, Gemini) |
| `/forge-security-pro` | Deep OWASP audit, hardening |
| `/forge-legal` | RGPD, CGV, auto-entrepreneur (French law) |

Install with: `/forge-update --pack business`

---

## Three Ways to Build

| Mode | Command | Best for |
|------|---------|----------|
| **Autopilot** | `/forge-auto "goal"` | Full pipeline, start to finish |
| **Parallel** | `/forge-team build STORY-001 STORY-002` | Multiple stories simultaneously |
| **Manual** | `/forge-build STORY-001` | One step at a time |

**Autopilot checkpoints**: `--no-pause` (fully autonomous), `--pause-stories` (default), `--pause-each` (approve every phase).

**Autonomous loops**: `/forge-loop` runs outside Claude Code with cost caps ($), circuit breakers, Docker sandbox, and git rollback. For overnight runs where "don't spend more than $10" matters.

---

## All Commands

### Pipeline

| Command | Agent | Output |
|---------|-------|--------|
| `/forge-auto` | All | Full pipeline (sequential) |
| `/forge-team` | All | Full pipeline (parallel) |
| `/forge-analyze` | Analyst | `docs/analysis.md` |
| `/forge-plan` | PM | `docs/prd.md` |
| `/forge-architect` | Architect | `docs/architecture.md` |
| `/forge-ux` | UX | `docs/ux-design.md` |
| `/forge-stories` | SM | `docs/stories/*.md` |
| `/forge-build` | Dev | Source + tests (TDD) |
| `/forge-debug` | Debug | Root cause + fix |
| `/forge-verify` | QA | Verdict (PASS/FAIL) |
| `/forge-review` | Reviewer | Adversarial code review |

### Tools

| Command | Purpose |
|---------|---------|
| `/forge-quick-spec` | Bug fix or small change (skip PRD) |
| `/forge-quick-test` | Run tests (auto-detects framework) |
| `/forge-audit` | Security audit (threat model, OWASP) |
| `/forge-audit-skill` | Audit a third-party skill |
| `/forge-party` | Multi-agent debate (2-3 perspectives) |
| `/forge-loop` | Autonomous iteration with guardrails |
| `/forge-memory` | Vector memory diagnostics |
| `/forge-init` | Initialize FORGE in a project |
| `/forge-resume` | Resume where you left off |
| `/forge-status` | Sprint dashboard |
| `/forge-update` | Update FORGE skills |

---

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git
- macOS, Linux, or Windows (via WSL)
- Python 3.9+ (optional -- for vector memory)
- [RTK](https://github.com/rtk-ai/rtk) (optional -- for 60-90% token compression, proposed at install)

### Quick Install

```bash
git clone https://github.com/fwehrling/forge.git /tmp/forge
bash /tmp/forge/install.sh            # Interactive (prompts for RTK, status line, etc.)
bash /tmp/forge/install.sh -y         # Non-interactive (accept all defaults)
```

The installer copies skills, configures hooks, and sets up vector memory automatically. Then in your project:

```bash
/forge-init
```

### Updating

From Claude Code:
```bash
/forge-update                    # Core skills
/forge-update --pack business    # + Business Pack
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
    memory/              # Persistent memory (Markdown + optional vector)
  docs/                  # Generated artifacts (PRD, architecture, stories...)
  CLAUDE.md              # Project conventions (auto-generated)

~/.claude/
  skills/forge-*/        # 23 core skills (+ 8 business pack)
  hooks/
    bash-interceptor.js  # Security + token optimization
    token-saver.sh       # Output filtering
    forge-update-check.sh # Update notifications
    forge-memory-sync.sh # Memory persistence
    statusline.sh        # Terminal status indicator
```

---

## Scale-Adaptive

FORGE adjusts to your project's complexity:

| Track | Scope | Agents |
|-------|-------|--------|
| **Quick** | Bug fix, hotfix | Dev only |
| **Standard** | Feature, module | PM, Architect, SM, Dev, QA |
| **Enterprise** | System, platform | All + Security + DevOps |

---

## Security

5-layer defense for autonomous execution: input validation, sandbox isolation, credential management, audit/rollback, and human gates.

- Autonomous loops run in Docker sandboxes with network whitelisting
- Dangerous commands blocked at the hook level (`rm -rf /`, `DROP DATABASE`, `git push --force main`...)
- Prompt injection protection across all skills that read external content
- Cost caps and circuit breakers prevent runaway spending

---

## Philosophy

1. **Artifacts over agents** -- Agents are disposable. The Markdown artifacts they produce persist forever.
2. **Memory over repetition** -- FORGE never asks the same question twice.
3. **Tests are first-class** -- Every story has test specs. Dev writes TDD. QA audits coverage.
4. **Security by default** -- Guardrails are built in, not bolted on.
5. **One command** -- `/forge-auto "goal"` and walk away. Or drill down with `/forge-*` for control.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

**Latest -- v1.7.20**: show FORGE version in status line when `.forge/` is detected.

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
