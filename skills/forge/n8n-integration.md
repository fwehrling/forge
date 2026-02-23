# n8n Integration Guide for FORGE

## Overview

FORGE integrates with n8n for workflow automation, CI/CD pipelines, and
multi-service orchestration. This enables FORGE to trigger and be triggered
by external events.

## Setup

### 1. n8n MCP Server Connection

```yaml
# .forge/mcp-servers.yml
servers:
  n8n:
    type: url
    url: 'http://localhost:5678/mcp' # n8n instance MCP endpoint
    auth_env: 'N8N_API_KEY'
    capabilities:
      - create_workflow
      - execute_workflow
      - list_workflows
      - get_executions
```

### 2. n8n-MCP Bridge (for Claude Code)

```json
// Claude Code MCP settings
{
  "mcpServers": {
    "n8n-mcp": {
      "command": "npx",
      "args": ["n8n-mcp"],
      "env": {
        "MCP_MODE": "stdio",
        "N8N_API_URL": "http://localhost:5678",
        "N8N_API_KEY": "${N8N_API_KEY}"
      }
    }
  }
}
```

### 3. Claude Code n8n Node

For n8n workflows that invoke Claude Code:

```bash
npm install -g @johnlindquist/n8n-nodes-claudecode
```

## Workflow Patterns

### Pattern 1: Git Push → Test → Deploy Pipeline

```json
{
  "name": "FORGE CI/CD Pipeline",
  "nodes": [
    {
      "type": "n8n-nodes-base.webhook",
      "name": "Git Push Webhook",
      "parameters": {
        "path": "forge-deploy",
        "httpMethod": "POST"
      }
    },
    {
      "type": "@johnlindquist/n8n-nodes-claudecode",
      "name": "Run FORGE Tests",
      "parameters": {
        "prompt": "/forge-verify --ci",
        "projectPath": "/srv/my-project"
      }
    },
    {
      "type": "n8n-nodes-base.if",
      "name": "Tests Pass?",
      "parameters": {
        "conditions": {
          "string": [{ "value1": "={{$json.exitCode}}", "value2": "0" }]
        }
      }
    },
    {
      "type": "@johnlindquist/n8n-nodes-claudecode",
      "name": "Build Production",
      "parameters": {
        "prompt": "/forge-build --production",
        "projectPath": "/srv/my-project"
      }
    },
    {
      "type": "n8n-nodes-base.ssh",
      "name": "Deploy to Server",
      "parameters": {
        "command": "cd /srv/my-project && ./scripts/deploy-direct.sh"
      }
    },
    {
      "type": "n8n-nodes-base.slack",
      "name": "Notify Team",
      "parameters": {
        "channel": "#deployments",
        "text": "✅ Deployed: {{$json.summary}}"
      }
    }
  ]
}
```

### Pattern 2: Issue → Story → Autonomous Loop

```json
{
  "name": "FORGE Auto-Implement",
  "nodes": [
    {
      "type": "n8n-nodes-base.githubTrigger",
      "name": "New Issue",
      "parameters": {
        "events": ["issues"],
        "filters": { "labels": ["auto-implement"] }
      }
    },
    {
      "type": "@johnlindquist/n8n-nodes-claudecode",
      "name": "Generate Story",
      "parameters": {
        "prompt": "/forge-stories --from-issue '{{$json.issue.body}}'",
        "projectPath": "/srv/my-project"
      }
    },
    {
      "type": "@johnlindquist/n8n-nodes-claudecode",
      "name": "Autonomous Loop Implementation",
      "parameters": {
        "prompt": "/forge-loop 'Implement {{$json.storyId}}' --max-iterations 20 --sandbox docker",
        "projectPath": "/srv/my-project",
        "timeout": 3600000
      }
    },
    {
      "type": "n8n-nodes-base.github",
      "name": "Create PR",
      "parameters": {
        "operation": "create",
        "resource": "pullRequest",
        "title": "feat: {{$json.summary}}",
        "body": "Auto-implemented by FORGE\n\n{{$json.changes}}"
      }
    }
  ]
}
```

### Pattern 3: Monitoring & Self-Healing

```json
{
  "name": "FORGE Health Monitor",
  "nodes": [
    {
      "type": "n8n-nodes-base.cron",
      "name": "Every 5 Minutes",
      "parameters": { "rule": { "interval": [{ "field": "minutes", "minutesInterval": 5 }] } }
    },
    {
      "type": "n8n-nodes-base.httpRequest",
      "name": "Health Check",
      "parameters": {
        "url": "https://api.myproject.com/health",
        "method": "GET"
      }
    },
    {
      "type": "n8n-nodes-base.if",
      "name": "Healthy?",
      "parameters": {
        "conditions": { "number": [{ "value1": "={{$json.statusCode}}", "value2": 200 }] }
      }
    },
    {
      "type": "@johnlindquist/n8n-nodes-claudecode",
      "name": "Diagnose & Fix",
      "parameters": {
        "prompt": "The health endpoint returned {{$json.statusCode}}. Check logs with 'podman logs camille-backend --tail 50' and diagnose the issue. If fixable, apply the fix.",
        "projectPath": "/srv/my-project"
      }
    },
    {
      "type": "n8n-nodes-base.telegram",
      "name": "Alert Owner",
      "parameters": {
        "chatId": "{{$env.TELEGRAM_CHAT_ID}}",
        "text": "⚠️ Health check failed. Auto-fix attempted: {{$json.result}}"
      }
    }
  ]
}
```

## FORGE Workflow Generator

Generate n8n workflows from FORGE config:

```bash
/forge-generate-workflow --type ci-cd --output n8n-deploy.json
/forge-generate-workflow --type monitoring --output n8n-monitor.json
/forge-generate-workflow --type auto-implement --output n8n-auto.json
```

The generator reads `.forge/config.yml` for:

- Deploy target (hostinger, docker, k8s, vercel)
- Notification channels (slack, telegram, email)
- MCP server connections
- Security gates

## Security Considerations

### n8n Instance Security

- Run n8n behind reverse proxy (Traefik) with HTTPS
- Use API key authentication for all MCP connections
- Store API keys in n8n credentials (encrypted), never in workflows
- Restrict webhook access to known IPs when possible

### Claude Code Node Security

- Set `projectPath` explicitly — never use user input for paths
- Set reasonable timeouts (prevent runaway loops)
- Use `--sandbox docker` for autonomous operations
- Never pass secrets in prompts — use environment variables
