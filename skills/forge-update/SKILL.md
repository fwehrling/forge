---
name: forge-update
description: >
  Updates FORGE skills from the latest GitHub release.
  Use when: "update forge", "upgrade forge skills", "new version of forge",
  "pull forge updates". Supports --pack business for the Business Pack.
---

# /forge-update — FORGE Updater

## Arguments

- No arguments: update core FORGE skills only
- `--pack business`: also install/update the Business Pack (marketing, SEO, legal, security, strategy agents)
- `--pack business --only`: install/update only the Business Pack without updating core skills

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
   # CRITICAL: Only copy forge-* skills. NEVER use rsync --delete or any command
   # that removes files not present in the source — this would destroy non-FORGE
   # skills (user-installed via skills.sh, custom skills, etc.)
   # Use \cp to bypass macOS cp -i alias that blocks non-interactive overwrites.
   for dir in "$TMPDIR/skills/"forge*/; do
     skill=$(basename "$dir")
     \cp -rf "$dir" ~/.claude/skills/"$skill"
   done
   # Also copy the main forge router skill
   \cp -rf "$TMPDIR/skills/forge/" ~/.claude/skills/forge/
   ```
   - **NEVER** use `rsync --delete`, `rsync -a --delete`, or any destructive sync
   - Only FORGE skills (`forge` and `forge-*`) are managed by this updater
   - Non-FORGE skills in `~/.claude/skills/` MUST be preserved (they belong to the user)
   - Le `README.md` du repo reste uniquement sur GitHub (pas copié dans les skills)

6. **Install packs** (if `--pack` argument provided) :
   - Read `$TMPDIR/packs.yaml` to get the list of skills in the requested pack
   - For each skill in the pack:
     - Compare `$TMPDIR/packs/<pack>/<skill>/` with `~/.claude/skills/<skill>/`
     - Copy if new or modified
   ```bash
   # Example for --pack business:
   for dir in "$TMPDIR/packs/business/"forge-*/; do
     skill=$(basename "$dir")
     \cp -rf "$dir" ~/.claude/skills/"$skill"
   done
   ```
   - If `--only` flag is set, skip core skills update (step 5) and jump directly here
   - Display which pack skills were installed/updated
   - If no `--pack` argument and business pack skills already exist locally, still update them
     (because they were previously installed and should stay in sync)
   ```bash
   # Auto-detect previously installed pack skills
   for dir in "$TMPDIR/packs/business/"forge-*/; do
     skill=$(basename "$dir")
     if [ -d ~/.claude/skills/"$skill" ]; then
       \cp -rf "$dir" ~/.claude/skills/"$skill"
     fi
   done
   ```

7. **Update version, hooks, and infrastructure** :
   - Lire `$TMPDIR/VERSION` et ecrire dans `~/.claude/skills/forge/.forge-version`
   - Vider le cache `~/.claude/skills/forge/.forge-update-cache` pour forcer un check frais au prochain demarrage
   - Lancer `forge-hooks-setup.sh` pour installer/mettre a jour les hooks FORGE (idempotent) :
     - `bash-interceptor.js` -- PreToolUse[Bash]: bloque les commandes dangereuses + optimisation tokens
     - `token-saver.sh` -- script d'execution pour le filtrage de sortie
     - `forge-update-check.sh` -- SessionStart: notification de mises a jour
     - `forge-memory-sync.sh` -- Stop: sync memoire vectorielle en fin de session
     - `statusline.sh` -- Status line: indicateur persistant FORGE dans la barre du terminal
   - Nettoie les hooks obsoletes (`command-validator.js`, `output-filter.js`, `forge-auto-router.js`)
   - Patche `~/.claude/settings.json` avec les hooks, permissions, et config statusLine (idempotent)
   ```bash
   \cp -f "$TMPDIR/VERSION" ~/.claude/skills/forge/.forge-version
   rm -f ~/.claude/skills/forge/.forge-update-cache
   bash ~/.claude/skills/forge/scripts/forge-hooks-setup.sh
   ```

8. **Suggest Business Pack** (if not installed and no `--pack` argument) :
   - Check if any skill from `$TMPDIR/packs/business/` exists in `~/.claude/skills/`
   - If none installed, display a one-time suggestion:
     ```
     Tip: FORGE Business Pack available (marketing, SEO, legal, security, strategy).
     Install with: /forge-update --pack business
     ```

9. **Update ~/.claude/CLAUDE.md** :
   - Comparer `$TMPDIR/templates/claude-md-forge-section.md` avec le bloc FORGE actuel dans `~/.claude/CLAUDE.md` (contenu entre `<!-- FORGE:BEGIN -->` et `<!-- FORGE:END -->`)
   - Si les marqueurs n'existent pas dans `~/.claude/CLAUDE.md` : lancer `bash "$TMPDIR/scripts/inject-claude-md.sh"` (demandera confirmation à l'utilisateur)
   - Si les marqueurs existent et le contenu est identique : afficher "CLAUDE.md FORGE section is up to date" et passer
   - Si les marqueurs existent et le contenu diffère :
     - Afficher le diff entre le bloc actuel et le template
     - Demander confirmation avant remplacement
     - Si confirmé : lancer `bash "$TMPDIR/scripts/inject-claude-md.sh"`
     - Si refusé : passer

10. **Verify installation** :
    - Confirmer que `~/.claude/skills/forge/SKILL.md` existe toujours
    - Compter le nombre de skills installés (core + pack si installé)

11. **Clean up** :
    ```bash
    rm -rf "$TMPDIR"
    ```

12. **Save memory** (if `.forge/` exists — ensures update history persists for version tracking and rollback reference):
    ```bash
    forge-memory log "FORGE mis à jour : v{OLD} → v{NEW}, {X} skills modifiés, {Y} nouveaux, pack business: {installed/not installed}" --agent update
    forge-memory consolidate --verbose
    forge-memory sync
    ```

13. **Display results** :

    ```
    FORGE Update — Complete
    ─────────────────────────
    Core    : X skills updated, Y new
    Pack    : Business Pack [installed / not installed]
              (Z skills updated)
    Total   : N skills installed
    Version : vX.Y.Z

    Note: Skills removed from the repo are NOT deleted locally (manual action required).
    Tip: Install Business Pack with /forge-update --pack business
    ```
