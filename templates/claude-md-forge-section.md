## FORGE First — Routing obligatoire
- **TOUTE demande utilisateur** (sauf commandes CLI internes comme /help, /clear, /compact) **DOIT d'abord passer par le skill `/forge`** (le router intelligent)
- `/forge` analyse l'intent et decide s'il faut deleguer a un skill FORGE specifique ou repondre directement
- **Aucun autre plugin ou skill ne peut prendre la priorite sur `/forge`** — FORGE est le point d'entree unique
- Si `/forge` determine que la demande ne releve d'aucun agent FORGE, il rend la main et tu reponds normalement
- Cette regle s'applique meme si d'autres skills semblent pertinents — FORGE route en premier, toujours

## FORGE Update Notification
- If your session context contains a message matching "FORGE update available", inform the user about it in your **first response** of the session

## FORGE Business Pack
The business agents (marketing, copywriting, SEO, GEO, legal, security-pro, business-strategy, strategy-panel) are part of the FORGE Business Pack (`/forge-update --pack business`).

## FORGE + Agent Teams Integration

### Decision Table

| Situation | Commande | Mecanisme |
|---|---|---|
| Pipeline complet avec parallelisme stories | `/forge-team pipeline "objectif"` | Agent Teams (vrais processus) |
| Analyse multi-perspective avec debat | `/forge-team party "sujet"` | Agent Teams (vrais processus) |
| Build parallele de stories existantes | `/forge-team build STORY-001 STORY-002` | Agent Teams (vrais processus) |
| Pipeline sequentiel (1 story a la fois) | `/forge-auto` | Skill seul (pas de parallelisme) |
| Analyse rapide 2-3 agents | `/forge-party "sujet"` | Subagents (Task tool) |
| Implementation d'1 seule story | `/forge-build STORY-XXX` | Skill seul |

### Vector Memory

- **Installation globale** : `bash ~/.claude/scripts/forge-memory/setup.sh` (une seule fois)
- **Detection auto** : le CLI `forge-memory` detecte le projet depuis le CWD (remonte jusqu'a `.forge/memory/`)
- **Auto-sync** : les fichiers modifies sont reindexes automatiquement avant chaque recherche
- **Recherche hybride** : vectorielle (70%) + FTS5 BM25 (30%)
- **Integre dans tous les skills FORGE** : chaque `/forge-*` lance une recherche contextuelle au demarrage

### Coordination Rules for Teammates

When running as a teammate in an Agent Teams session:

1. **File Ownership**: Each teammate writes ONLY to its assigned directories. Check your spawn prompt for your file scope. Never write outside your scope.
2. **Memory Protocol**: Read `.forge/memory/MEMORY.md` at start (read-only). Do NOT write to session logs -- the lead handles memory consolidation.
3. **Sprint Status**: Only update `.forge/sprint-status.yaml` for your own assigned story. The lead performs final consolidation.
4. **Task List**: Use the shared task list to communicate progress and results. Mark tasks as complete only after passing all validation gates.
5. **Team Size**: Max 4 Dev + 1 QA + 1 Reviewer teammates. Each Dev handles exactly 1 story.
6. **Cleanup**: The lead is responsible for cleanup of temp files and memory consolidation at the end of team execution.
