## Skill Priority
- **FORGE skills first**: When a FORGE project is detected (`.forge/` directory exists), always prefer FORGE skills (`/forge-*`) over other skills for development tasks (planning, architecture, building, testing, reviewing, deploying)
- **Mapping intent → FORGE skill**:
  - Build/implement/code → `/forge-build` or `/forge-auto`
  - Test/verify/QA → `/forge-verify` or `/forge-quick-test`
  - Review/audit code → `/forge-review`
  - Plan/requirements → `/forge-plan`
  - Architecture/design → `/forge-architect`
  - Security audit → `/forge-audit`
  - Deploy → `/forge-deploy`
  - Full project → `/forge-auto`
- **Non-FORGE skills**: Use only when no FORGE skill matches (e.g., `google-calendar`, `stripe-integration`, `hostinger-infra`)

## FORGE + Agent Teams Integration

### Decision Table: Which Tool to Use

| Situation | Commande | Mécanisme |
|---|---|---|
| Pipeline complet avec parallélisme stories | `/forge-team pipeline "objectif"` | Agent Teams (vrais processus) |
| Analyse multi-perspective avec débat | `/forge-team party "sujet"` | Agent Teams (vrais processus) |
| Build parallèle de stories existantes | `/forge-team build STORY-001 STORY-002` | Agent Teams (vrais processus) |
| Pipeline séquentiel (1 story à la fois) | `/forge-auto` | Skill seul (pas de parallélisme) |
| Analyse rapide 2-3 agents | `/forge-party "sujet"` | Subagents (Task tool) |
| Implémentation d'1 seule story | `/forge-build STORY-XXX` | Skill seul |

### Vector Memory

- **Installation globale** : `bash ~/.claude/scripts/forge-memory/setup.sh` (une seule fois)
- **Détection auto** : le CLI `forge-memory` détecte le projet depuis le CWD (remonte jusqu'à `.forge/memory/`)
- **Auto-sync** : les fichiers modifiés sont réindexés automatiquement avant chaque recherche
- **Recherche hybride** : vectorielle (70%) + FTS5 BM25 (30%)
- **Intégré dans tous les skills FORGE** : chaque `/forge-*` lance une recherche contextuelle au démarrage

### Coordination Rules for Teammates

When running as a teammate in an Agent Teams session:

1. **File Ownership**: Each teammate writes ONLY to its assigned directories. Check your spawn prompt for your file scope. Never write outside your scope.
2. **Memory Protocol**: Read `.forge/memory/MEMORY.md` at start (read-only). Do NOT write to session logs — the lead handles memory consolidation.
3. **Sprint Status**: Only update `.forge/sprint-status.yaml` for your own assigned story. The lead performs final consolidation.
4. **Task List**: Use the shared task list to communicate progress and results. Mark tasks as complete only after passing all validation gates.
5. **Team Size**: Max 4 Dev + 1 QA + 1 Reviewer teammates. Each Dev handles exactly 1 story.
6. **Cleanup**: The lead is responsible for cleanup of temp files and memory consolidation at the end of team execution.
