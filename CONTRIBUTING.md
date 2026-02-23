# Contributing to FORGE

Thank you for your interest in contributing to FORGE!

## License

By submitting a pull request, you agree that your contribution will be licensed under the [MIT License](LICENSE) that covers this project. You retain copyright on your contributions.

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/forge.git
   cd forge
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/my-improvement
   ```

## Project Structure

```
forge/
  README.md              # Main documentation (features, installation, usage)
  CLAUDE.md              # Repo conventions and Agent Teams coordination rules
  LICENSE                # MIT License
  CONTRIBUTING.md        # This file
  CHANGELOG.md           # Release history (Keep a Changelog format)
  VERSION                # Current version (semver)
  install.sh             # Cross-platform installer
  hooks/                 # Claude Code hooks
    forge-update-check.sh
  skills/                # All FORGE skills (one directory per skill)
    forge/               # Core framework (SKILL.md + scripts + integration guides)
      SKILL.md           # Main framework reference document
      forge-init.sh      # Project initialization script
      forge-loop.sh      # Autonomous loop runner
      audit-skill.py     # Skill security auditor
      scripts/           # Python packages (forge-memory, token-saver)
    forge-build/         # Dev agent skill
    forge-verify/        # QA agent skill
    forge-auto/          # Autopilot skill
    ...                  # 23 skills total
```

## Adding a New Skill

Each skill is a directory under `skills/` containing at minimum a `SKILL.md` file.

### Skill Structure

```markdown
---
name: forge-my-skill
description: >
  Short description of what the skill does.
  Usage: /forge-my-skill
---

# /forge-my-skill — Title

## French Language Rule

All content generated in French MUST use proper accents...

## Workflow

1. **Load context**: Read memory files
2. Perform the skill's work
3. **Save memory** (MANDATORY)
```

### Checklist for New Skills

- [ ] `SKILL.md` follows the frontmatter YAML + Markdown pattern
- [ ] French Language Rule section is present
- [ ] Memory protocol is followed (load at start, save at end)
- [ ] Skill is added to the Commands table in `README.md` (Pipeline or Orchestration & Tools)
- [ ] Skill is added to the Agent Registry in `skills/forge/SKILL.md` section 1.1 (if it's an agent)
- [ ] Skill is added to the Quick Start in `skills/forge/SKILL.md` (if it's a pipeline command)
- [ ] Skill is added to `install.sh` verification loop
- [ ] `CHANGELOG.md` is updated (add an `[Unreleased]` section if it doesn't exist)

## Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add forge-ux skill
fix: correct --scale parsing in forge-init.sh
docs: update README command tables
refactor: extract argument parser in forge-loop.sh
```

- Prefix in lowercase: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`
- Description starts with lowercase after the prefix
- Commit messages in English

## Pull Requests

1. **One PR per logical change** (don't mix unrelated fixes)
2. **Rebase your branch on main** before submitting (keep a clean linear history)
3. **Describe your changes** in the PR body
4. **Test your changes** (see [Testing](#testing) below)
5. **Wait for review** — the maintainer reviews all PRs and decides whether to merge. Do not expect auto-merge.

## Testing

Before submitting a PR, verify your changes:

### Skills

```bash
# Count skills (should match expected total)
find skills/ -name SKILL.md | wc -l

# Test install.sh in a temp directory
cp -r . /tmp/forge-test && bash /tmp/forge-test/install.sh && rm -rf /tmp/forge-test

# Test the skill manually in Claude Code if possible
```

### Shell scripts

```bash
# Lint with shellcheck (if installed)
shellcheck skills/forge/forge-init.sh
shellcheck skills/forge/forge-loop.sh
shellcheck hooks/forge-update-check.sh

# Test forge-init.sh argument parsing
mkdir /tmp/forge-init-test
bash skills/forge/forge-init.sh /tmp/forge-init-test --scale standard
cat /tmp/forge-init-test/.forge/config.yml  # verify scale: standard
ls /tmp/forge-init-test/.forge/memory/MEMORY.md  # verify MEMORY.md created
rm -rf /tmp/forge-init-test
```

### Consistency checks

```bash
# Verify every command in Quick Start has a matching skill
grep '/forge-' skills/forge/SKILL.md | grep -oP '/forge-[\w-]+' | sort -u | while read cmd; do
  skill="${cmd#/}"
  [ -f "skills/${skill}/SKILL.md" ] || echo "MISSING: ${skill}"
done

# Verify no broken cross-references in cache paths, file paths, etc.
grep -r '~/.claude/' skills/ hooks/ | grep -v node_modules
```

## Code Style

### Shell scripts (Bash)
- `set -euo pipefail` at the top
- Use `local` for variables inside functions (never `local` outside a function)
- Quote all variables (`"$var"`, not `$var`)
- Use `while/case` for argument parsing (not positional `$1`/`$2`)

### Python scripts
- Python 3.9+ minimum
- PEP 8 style
- No global dependencies — use isolated venvs (see `scripts/forge-memory/setup.sh`)
- Type hints encouraged but not required

### SKILL.md files
- Follow the existing pattern exactly: frontmatter, French Language Rule, Workflow, Save memory
- Agent skills reference their persona from `references/agents/*.md`

### Markdown
- ATX headings (`#`)
- Fenced code blocks with language tags

## Reporting Issues

Open an issue on GitHub with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Your OS and Claude Code version
