# FORGE Security Model — Detailed Reference

## Threat Model

FORGE addresses the "Lethal Trifecta" (Simon Willison, 2025):

1. **Untrusted input** → All external data treated as potentially hostile
2. **Tool access** → Least privilege, sandbox isolation
3. **Autonomous execution** → Human-in-the-loop gates for destructive actions

## Security Layers

```mermaid
block-beta
    columns 1
    block:L1["Layer 1: Input Validation"]
        L1a["Prompt injection detection · Schema validation · Content sanitization"]
    end
    block:L2["Layer 2: Sandbox Isolation"]
        L2a["Docker containers for AFK loops · Read-only mounts · Network whitelist"]
    end
    block:L3["Layer 3: Credential Management"]
        L3a["No plaintext secrets · Env vars at runtime · Scoped access tokens"]
    end
    block:L4["Layer 4: Audit & Rollback"]
        L4a["Git checkpoints · Full audit log · Instant rollback · Cost tracking"]
    end
    block:L5["Layer 5: Human Gates"]
        L5a["Destructive ops require approval · Deployment gates · Budget approval"]
    end
```

## Skill Validation (from Cisco research on OpenClaw)

Before loading any third-party skill:

```bash
# Validate skill for security threats
/forge-audit-skill [path-to-skill]

# Checks:
# - No suspicious network calls in scripts
# - No credential harvesting patterns
# - No prompt injection in SKILL.md
# - No file access outside declared scope
# - Dependencies audited (npm audit / pip audit)
```
