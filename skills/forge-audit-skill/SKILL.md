---
name: forge-audit-skill
description: >
  FORGE Skill Auditor — Security audit of third-party Claude Code skills before installation.
  Use when the user says "audit this skill", "is this skill safe to install", "check this skill
  for security issues", "review a third-party skill", "skill security check",
  or wants to verify a skill for prompt injection, data exfiltration, or malicious behavior
  before installing it. Analyzes SKILL.md and bundled scripts for threat patterns.
  Do NOT use for project security audit (use /forge-audit).
  Do NOT use for code review of project files (use /forge-review).
  Usage: /forge-audit-skill [path-to-skill]
---

# /forge-audit-skill — FORGE Skill Auditor

This skill wraps `audit-skill.py` to validate third-party skills for security threats before installation.

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

1. **Load context** (if `.forge/` exists):
   - Read `.forge/memory/MEMORY.md` for project context
   - `forge-memory search "<skill-name> audit security" --limit 3`
     → Load relevant past audit findings

2. Validate that a skill path argument is provided
3. Verify the path exists and contains a `SKILL.md` file
4. Locate the `audit-skill.py` script at `~/.claude/skills/forge/audit-skill.py`
5. Execute the audit:
   ```bash
   python3 ~/.claude/skills/forge/audit-skill.py "<path-to-skill>"
   ```

6. **Display the audit report**:

   ```
   FORGE Skill Audit — <skill-name>
   ──────────────────────────────────
   Risk Level : LOW | MEDIUM | HIGH | CRITICAL

   ## Findings

   ### Network & Data Exfiltration
   - <finding or "None detected">

   ### Credential Harvesting
   - <finding or "None detected">

   ### Prompt Injection
   - <finding or "None detected">

   ### File Access
   - <finding or "None detected">

   ### Obfuscated Code
   - <finding or "None detected">

   ## Recommendation
   <install / install with caution / do NOT install>
   ```

7. If HIGH or CRITICAL findings: warn the user explicitly before installation

8. **Save memory** (if `.forge/` exists — ensures audit findings persist for security tracking and re-audit comparison):
   ```bash
   forge-memory log "Audit skill : {SKILL_NAME}, risque {LEVEL}, {N} findings, recommandation: {RECOMMENDATION}" --agent security
   forge-memory consolidate --verbose
   forge-memory sync
   ```
