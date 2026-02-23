# FORGE Security Model

## Overview

FORGE addresses the security gaps identified in autonomous AI agents (OpenClaw/Moltbot)
by implementing defense-in-depth across five layers.

## The Lethal Trifecta (Simon Willison, 2025)

Autonomous AI agents face three compounding risks:

1. **Untrusted Input**: Data from web, messages, APIs may contain prompt injection
2. **Tool Access**: Agents can execute code, access files, make network calls
3. **Autonomy**: No human reviewing each action in real-time

FORGE mitigates each:

## Layer 1: Input Validation

### Prompt Injection Defense

- All external data (MCP responses, webhook payloads, file contents) passes through
  sanitization before entering agent context
- Pattern detection for common injection techniques:
  - Instruction override attempts ("ignore previous instructions")
  - Role manipulation ("you are now a...")
  - Delimiter exploitation (closing tags, markdown breaks)

### Schema Validation

```typescript
// All MCP tool inputs validated with Zod
const createWorkflowInput = z.object({
  name: z.string().min(1).max(200),
  nodes: z.array(nodeSchema).max(50),
  // No arbitrary string fields that could contain injections
});
```

### Content Sanitization

- Strip HTML/script tags from user-provided content
- Limit string lengths to prevent context flooding
- Validate URLs against allowlist before fetching

## Layer 2: Sandbox Isolation

### Autonomous Loop Sandboxing

```yaml
# Every AFK (Away From Keyboard) loop MUST run in sandbox
sandbox:
  provider: docker
  image: 'forge-sandbox:latest'

  # Filesystem isolation
  mount_readonly:
    - ./docs # Specs and stories (read-only)
    - ./references # Reference material
  mount_readwrite:
    - ./src # Source code (read-write)
    - ./tests # Tests

  # NO access to:
  # - ~/.ssh/          # SSH keys
  # - ~/.aws/          # Cloud credentials
  # - ~/.gitconfig     # Git auth tokens
  # - ~/.npm/          # NPM tokens

  # Network isolation
  network:
    mode: restricted
    allowed:
      - 'registry.npmjs.org:443'
      - 'pypi.org:443'
      - 'github.com:443'
    blocked:
      - '*' # Everything else blocked

  # Resource limits
  limits:
    memory: '2g'
    cpu: '2'
    timeout: '60m'
```

### HITL vs AFK Modes

- **HITL (Human-In-The-Loop)**: Sandbox optional — human observing
- **AFK (Away From Keyboard)**: Sandbox MANDATORY — no human oversight
- **Production Deploy**: ALWAYS requires human approval gate

## Layer 3: Credential Management

### Rules

1. **NEVER** store secrets in config files, SKILL.md, or any versioned file
2. **NEVER** pass secrets as command-line arguments (visible in process list)
3. **ALWAYS** use environment variables injected at runtime
4. **ALWAYS** use scoped tokens with minimum required permissions

### Pattern

```yaml
# .forge/config.yml — Reference env vars, NEVER values
deploy:
  api_key_env: 'DEPLOY_API_KEY' # Name of env var
  # NOT: api_key: "sk-abc123..."   # NEVER this

mcp:
  servers:
    github:
      auth_env: 'GITHUB_TOKEN' # Name of env var
```

```bash
# Runtime injection (never committed to git)
export DEPLOY_API_KEY="sk-abc123..."
export GITHUB_TOKEN="ghp_xyz..."
forge-loop "deploy to staging"
```

### .gitignore Requirements

```
# FORGE security — always ignored
.env
.env.*
*.pem
*.key
.forge/secrets/
```

## Layer 4: Audit & Rollback

### Git Checkpoints

Before each autonomous loop iteration:

```bash
git stash push -m "forge-checkpoint-$(date +%s)"
# OR
git commit -m "forge(checkpoint): pre-iteration state"
```

After loop completes, squash checkpoint commits:

```bash
git rebase -i HEAD~N  # Squash iteration commits
```

### Audit Log

Every tool invocation logged to `.forge/audit.log`:

```json
{
  "timestamp": "2026-02-03T10:30:00Z",
  "agent": "dev",
  "action": "file_write",
  "target": "src/auth/auth.service.ts",
  "iteration": 5,
  "loop_id": "forge-loop-abc123"
}
```

### Cost Tracking

```json
{
  "loop_id": "forge-loop-abc123",
  "iterations": 15,
  "tokens_input": 450000,
  "tokens_output": 120000,
  "estimated_cost_usd": 3.42,
  "cap_usd": 10.0,
  "status": "completed"
}
```

## Layer 5: Human Gates

### Destructive Operations Requiring Approval

- Production deployment
- Database migration (production)
- Secret rotation
- Infrastructure changes (scaling, DNS)
- Dependency updates (major versions)

### Gate Implementation

```yaml
# In n8n workflow or FORGE config
gates:
  production_deploy:
    type: manual_approval
    approvers: ['team-lead']
    timeout: '24h'
    on_timeout: reject

  database_migration:
    type: manual_approval
    require_backup: true
    rollback_plan: required
```

## Skill Auditing

### /forge-audit-skill Command

Scan third-party skills for security threats:

```python
# Checks performed:
checks = [
    "no_network_calls_in_scripts",      # No curl/wget/fetch in scripts
    "no_credential_patterns",            # No API key/token patterns
    "no_prompt_injection",               # No injection patterns in SKILL.md
    "no_file_access_outside_scope",      # No ../../ path traversal
    "dependencies_audited",              # npm audit / pip audit clean
    "no_eval_or_exec",                   # No dynamic code execution
    "no_environment_variable_reads",     # No os.environ access for secrets
]
```

### Risk Score

Each skill gets a risk score (0-100):

- 0-20: Low risk (pure documentation/reference)
- 21-50: Medium risk (has scripts, needs review)
- 51-80: High risk (network access, file operations)
- 81-100: Critical risk (credential access, system commands)

Only skills scoring ≤50 are auto-approved. Higher scores require explicit human approval.
