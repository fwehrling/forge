---
name: forge-update
description: >
  FORGE Updater — Updates all FORGE skills from the latest GitHub release.
  Usage: /forge-update
---

# /forge-update — FORGE Updater

## French Language Rule

All content generated in French MUST use proper accents (é, è, ê, à, ù, ç, ô, î, etc.), follow French grammar rules (agreements, conjugations), and use correct spelling.

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

5. **Copier les fichiers mis à jour** :
   ```bash
   cp -rf "$TMPDIR/skills/"* ~/.claude/skills/
   ```
   - Le `README.md` du repo reste uniquement sur GitHub (pas copié dans les skills)

5b. **Mettre à jour la version et le hook** :
   - Lire `$TMPDIR/VERSION` et écrire dans `~/.claude/skills/forge/.forge-version`
   - Copier `$TMPDIR/hooks/forge-update-check.sh` vers `~/.claude/hooks/forge-update-check.sh` (chmod +x)
   - Vider le cache `~/.claude/skills/forge/.forge-update-cache` pour forcer un check frais au prochain démarrage
   ```bash
   cp "$TMPDIR/VERSION" ~/.claude/skills/forge/.forge-version
   cp "$TMPDIR/hooks/forge-update-check.sh" ~/.claude/hooks/forge-update-check.sh
   chmod +x ~/.claude/hooks/forge-update-check.sh
   rm -f ~/.claude/skills/forge/.forge-update-cache
   ```

5c. **Mettre à jour ~/.claude/CLAUDE.md** :
   - Comparer `$TMPDIR/templates/claude-md-forge-section.md` avec le bloc FORGE actuel dans `~/.claude/CLAUDE.md` (contenu entre `<!-- FORGE:BEGIN -->` et `<!-- FORGE:END -->`)
   - Si les marqueurs n'existent pas dans `~/.claude/CLAUDE.md` : lancer `bash "$TMPDIR/scripts/inject-claude-md.sh"` (demandera confirmation à l'utilisateur)
   - Si les marqueurs existent et le contenu est identique : afficher "CLAUDE.md FORGE section is up to date" et passer
   - Si les marqueurs existent et le contenu diffère :
     - Afficher le diff entre le bloc actuel et le template
     - Demander confirmation avant remplacement
     - Si confirmé : lancer `bash "$TMPDIR/scripts/inject-claude-md.sh"`
     - Si refusé : passer

6. **Vérifier l'installation** :
   - Confirmer que `~/.claude/skills/forge/SKILL.md` existe toujours
   - Compter le nombre de skills installés

7. **Nettoyer** :
   ```bash
   rm -rf "$TMPDIR"
   ```

8. **Afficher le résultat final** :
   - Nombre de skills mis à jour / ajoutés / supprimés
   - Nombre total de skills installés
   - Rappel : les skills supprimés du repo ne sont PAS supprimés localement (action manuelle requise)
