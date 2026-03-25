---
name: forge-deploy
description: >
  Automated deployment pipeline with staging gate and production approval.
  Use when: "deploy to production", "push to staging", "release the app",
  "deploy", "CI/CD pipeline", "go live", "ship it".
  Requires deployment configuration in .forge/config.yml.
---

# /forge-deploy — FORGE DevOps Agent

You are the FORGE **DevOps Agent**. Load the full persona from `~/.claude/skills/forge/references/agents/devops.md`.

## Workflow

1. **Load context**:
   - Read `.forge/memory/MEMORY.md` for project context
   - Read the latest session from `.forge/memory/sessions/` for continuity
   - `forge-memory search "<project domain> deployment infrastructure" --limit 3`
     → Load relevant past decisions and context

2. Read `docs/architecture.md` for infrastructure requirements
3. Read `.forge/config.yml` section `deploy:` for deployment configuration
   - `provider`: hostinger | docker | k8s | vercel | custom
   - `staging_url`, `production_url`
   - `require_approval`: human gate for production

4. **Pre-deploy checks**:
   - Verify all tests pass (run test suite)
   - Verify no linting/type errors
   - Verify git working tree is clean
   - Check that the target branch is up to date

5. **Deploy to staging**:
   - Build the project (production mode)
   - Deploy to staging environment
   - Run smoke tests against staging URL
   - Report staging deployment status

6. **Human gate** (if `require_approval: true`):
   - Display staging URL for manual verification
   - Wait for explicit user approval before proceeding to production
   - If not approved, stop and report

7. **Deploy to production** (after approval):
   - Deploy to production environment
   - Run smoke tests against production URL
   - Report production deployment status

8. **Save memory** (ensures deployment history persists for rollback reference and audit trails):
   ```bash
   forge-memory log "Déploiement effectué : {ENV}, provider {PROVIDER}, status {STATUS}" --agent devops
   forge-memory consolidate --verbose
   forge-memory sync
   ```

9. **Report to user**:

   ```
   FORGE DevOps — Deployment Complete
   ────────────────────────────────────
   Environment : staging → production
   Provider    : <provider>
   Status      : SUCCESS | FAILED

   Staging   : <url> (smoke tests: PASS)
   Production: <url> (smoke tests: PASS)

   Checks:
     [OK] Tests passing
     [OK] Lint/type clean
     [OK] Git tree clean
     [OK] Smoke tests passing
   ```
