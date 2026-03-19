---
name: forge-update
description: >
  FORGE Updater — Updates all FORGE skills from the latest GitHub release.
  Use when the user says "update forge", "upgrade forge skills", "is there a new version of forge",
  "get the latest forge", "pull forge updates", or wants to update their local FORGE installation
  to the latest version from GitHub. Downloads and replaces all skill files.
  Do NOT use for updating project-specific configuration (edit .forge/config.yml manually).
  Do NOT use for initializing FORGE (use /forge-init).
  Usage: /forge-update
---

# /forge-update — FORGE Updater

## Workflow

1. **Vérifier que FORGE est installé** :
   - Vérifier que `~/.claude/skills/forge/SKILL.md` existe
   - Si absent, afficher une erreur et suggérer l'installation via `install.sh`

2. **Cloner le repo** :
   ```bash
   TMPDIR="/tmp/forge-update-$(date +%Y-%m-%d)"
   rm -rf "$TMPDIR"
   git clone --depth 1 https://github.com/fwehrling/forge.git "$TMPDIR"
   ```

3. **Comparer les skills** :
   - Pour chaque dossier dans `$TMPDIR/skills/*/` :
     - Comparer avec `~/.claude/skills/<skill>/` via `diff -rq`
     - Classer en 3 catégories : **modifiés**, **nouveaux**, **supprimés**
   - Afficher un résumé clair des changements détectés

4. **Afficher le résumé des changements** :
   - Lister les skills modifiés avec les fichiers concernés
   - Lister les nouveaux skills
   - Lister les skills supprimés (présents localement mais absents du repo)
   - Si aucun changement, afficher "FORGE est déjà à jour" et terminer

5. **Copy updated files** :
   ```bash
   cp -rf "$TMPDIR/skills/"* ~/.claude/skills/
   ```
   - Le `README.md` du repo reste uniquement sur GitHub (pas copié dans les skills)

6. **Update version and hook** :
   - Lire `$TMPDIR/VERSION` et écrire dans `~/.claude/skills/forge/.forge-version`
   - Copier `$TMPDIR/hooks/forge-update-check.sh` vers `~/.claude/hooks/forge-update-check.sh` (chmod +x)
   - Vider le cache `~/.claude/skills/forge/.forge-update-cache` pour forcer un check frais au prochain démarrage
   ```bash
   cp "$TMPDIR/VERSION" ~/.claude/skills/forge/.forge-version
   cp "$TMPDIR/hooks/forge-update-check.sh" ~/.claude/hooks/forge-update-check.sh
   chmod +x ~/.claude/hooks/forge-update-check.sh
   rm -f ~/.claude/skills/forge/.forge-update-cache
   ```

7. **Update ~/.claude/CLAUDE.md** :
   - Comparer `$TMPDIR/templates/claude-md-forge-section.md` avec le bloc FORGE actuel dans `~/.claude/CLAUDE.md` (contenu entre `<!-- FORGE:BEGIN -->` et `<!-- FORGE:END -->`)
   - Si les marqueurs n'existent pas dans `~/.claude/CLAUDE.md` : lancer `bash "$TMPDIR/scripts/inject-claude-md.sh"` (demandera confirmation à l'utilisateur)
   - Si les marqueurs existent et le contenu est identique : afficher "CLAUDE.md FORGE section is up to date" et passer
   - Si les marqueurs existent et le contenu diffère :
     - Afficher le diff entre le bloc actuel et le template
     - Demander confirmation avant remplacement
     - Si confirmé : lancer `bash "$TMPDIR/scripts/inject-claude-md.sh"`
     - Si refusé : passer

8. **Verify installation** :
   - Confirmer que `~/.claude/skills/forge/SKILL.md` existe toujours
   - Compter le nombre de skills installés

9. **Clean up** :
   ```bash
   rm -rf "$TMPDIR"
   ```

10. **Save memory** (if `.forge/` exists — ensures update history persists for version tracking and rollback reference):
    ```bash
    forge-memory log "FORGE mis à jour : v{OLD} → v{NEW}, {X} skills modifiés, {Y} nouveaux" --agent update
    forge-memory consolidate --verbose
    forge-memory sync
    ```

11. **Display results** :

    ```
    FORGE Update — Complete
    ─────────────────────────
    Updated : X skills
    Added   : Y new skills
    Removed : Z skills (from repo, still present locally)
    Total   : N skills installed
    Version : vX.Y.Z

    Note: Skills removed from the repo are NOT deleted locally (manual action required).
    ```
