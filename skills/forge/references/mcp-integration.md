# FORGE MCP Integration -- Detailed Reference (Conceptual)

> This section describes planned MCP integration patterns. These are not yet implemented
> as code -- they serve as a design reference for future development. See
> `~/.claude/skills/forge/n8n-integration.md` for the integration guide.

## FORGE as MCP Server (Planned)

FORGE could expose its capabilities as MCP tools for external clients.

```typescript
// FORGE MCP Server -- exposes development tools
tools: [
  'forge_analyze', // Run analysis phase
  'forge_plan', // Generate PRD
  'forge_architect', // Generate architecture
  'forge_build', // Run implementation loop
  'forge_verify', // Run test suite
  'forge_deploy', // Deploy to environment
  'forge_status', // Get project status
  'forge_loop', // Start autonomous loop
];
```

## Consuming MCP Servers (Planned)

FORGE could connect to external MCP servers for enhanced capabilities:

```yaml
# .forge/mcp-servers.yml
servers:
  n8n:
    url: 'http://localhost:5678/mcp'
    auth: api_key
    tools: [create_workflow, execute_workflow, list_workflows]

  github:
    url: 'https://mcp.github.com'
    auth: oauth
    tools: [create_issue, create_pr, list_issues]

  database:
    url: 'http://localhost:3001/mcp'
    auth: api_key
    tools: [query, migrate, backup]
    readonly: true # Security: read-only by default
```

## n8n Workflow Automation (Planned)

FORGE could generate n8n workflows for CI/CD automation:

```json
{
  "name": "FORGE Deploy Pipeline",
  "nodes": [
    { "type": "webhook", "name": "Git Push Trigger" },
    { "type": "claude-code", "name": "Run Tests", "params": { "prompt": "/forge-verify" } },
    { "type": "if", "name": "Tests Pass?" },
    { "type": "claude-code", "name": "Build", "params": { "prompt": "/forge-build --production" } },
    { "type": "ssh", "name": "Deploy to Server" },
    { "type": "slack", "name": "Notify Team" }
  ]
}
```
