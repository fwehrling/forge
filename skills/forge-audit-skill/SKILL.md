---
name: forge-audit-skill
description: >
  FORGE Skill Auditor — Security audit of third-party Claude Code skills.
  Usage: /forge-audit-skill <path-to-skill>
---

# /forge-audit-skill — FORGE Skill Auditor

This skill wraps `audit-skill.py` to validate third-party skills for security threats before installation.

## French Language Rule

All content generated in French MUST use proper accents (é, è, ê, à, ù, ç, ô, î, etc.), follow French grammar rules (agreements, conjugations), and use correct spelling.

## Usage

```bash
/forge-audit-skill /path/to/skill-directory
/forge-audit-skill ~/.claude/skills/some-third-party-skill
```

## What It Checks

- **Suspicious network calls** in scripts (curl, wget, fetch to unknown domains)
- **Credential harvesting patterns** (reading .env, passwords, tokens, API keys)
- **Prompt injection** in SKILL.md (attempts to override system instructions)
- **File access outside declared scope** (reading/writing files beyond the skill directory)
- **Dependency audit** (npm audit / pip audit for bundled dependencies)
- **Obfuscated code** (base64 encoded strings, eval patterns)

## Workflow

1. Validate that a skill path argument is provided
2. Verify the path exists and contains a `SKILL.md` file
3. Locate the `audit-skill.py` script at `~/.claude/skills/forge/audit-skill.py`
4. Execute the audit:
   ```bash
   python3 ~/.claude/skills/forge/audit-skill.py "<path-to-skill>"
   ```
5. Display the audit report:
   - Risk level: LOW / MEDIUM / HIGH / CRITICAL
   - Findings categorized by type
   - Recommendations
6. If HIGH or CRITICAL findings: warn the user explicitly before installation
