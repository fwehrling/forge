---
name: forge-update
description: >
  Updates FORGE skills from GitHub. Supports --pack business.
---

# /forge-update — FORGE Updater

## Arguments

- No arguments: update core FORGE skills only
- `--pack business`: also install/update the Business Pack (marketing, SEO, legal, security, strategy agents)
- `--pack business --only`: install/update only the Business Pack without updating core skills

## Workflow

1. **Verify FORGE is installed** :
   - Check that `~/.claude/skills/forge/SKILL.md` exists
   - If missing, display an error and suggest installing via `install.sh`

2. **Clone the repo** :
   ```bash
   FORGE_TMPDIR="/tmp/forge-update-$(date +%Y-%m-%d)"
   rm -rf "$FORGE_TMPDIR"
   git clone --depth 1 https://github.com/fwehrling/forge.git "$FORGE_TMPDIR"
   ```
   > **Important**: use `FORGE_TMPDIR`, NOT `TMPDIR` — `TMPDIR` is a macOS system variable (`/var/folders/...`) and would cause path errors.

3. **Compare skills** :
   - For each directory in `$FORGE_TMPDIR/skills/*/` :
     - Compare with `~/.claude/skills/<skill>/` via `diff -rq`
     - Classify into 3 categories: **modified**, **new**, **removed**
   - Display a clear summary of detected changes

4. **Display change summary** :
   - List modified skills with affected files
   - List new skills
   - List removed skills (present locally but absent from repo)
   - If no changes, display "FORGE is already up to date" and stop

5. **Copy updated files** :
   ```bash
   # CRITICAL: Only copy forge-* skills. NEVER use rsync --delete or any command
   # that removes files not present in the source — this would destroy non-FORGE
   # skills (user-installed via skills.sh, custom skills, etc.)
   # Use \cp to bypass macOS cp -i alias that blocks non-interactive overwrites.
   for dir in "$FORGE_TMPDIR/skills/"forge*/; do
     skill=$(basename "$dir")
     \cp -rf "$dir" ~/.claude/skills/"$skill"
   done
   # Also copy the main forge router skill
   \cp -rf "$FORGE_TMPDIR/skills/forge/" ~/.claude/skills/forge/
   ```
   - **NEVER** use `rsync --delete`, `rsync -a --delete`, or any destructive sync
   - Only FORGE skills (`forge` and `forge-*`) are managed by this updater
   - Non-FORGE skills in `~/.claude/skills/` MUST be preserved (they belong to the user)
   - The repo `README.md` stays on GitHub only (not copied into skills)
   - **Remove deprecated skills** that no longer exist in the repo:
   ```bash
   REMOVED_SKILLS="forge-deploy"
   for skill in $REMOVED_SKILLS; do
     if [ -d ~/.claude/skills/"$skill" ]; then
       rm -rf ~/.claude/skills/"$skill"
       echo "Removed deprecated: $skill"
     fi
   done
   ```

6. **Install packs** (if `--pack` argument provided) :
   - Read `$FORGE_TMPDIR/packs.yaml` to get the list of skills in the requested pack
   - For each skill in the pack:
     - Compare `$FORGE_TMPDIR/packs/<pack>/<skill>/` with `~/.claude/skills/<skill>/`
     - Copy if new or modified
   ```bash
   # Example for --pack business:
   for dir in "$FORGE_TMPDIR/packs/business/"forge-*/; do
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
   for dir in "$FORGE_TMPDIR/packs/business/"forge-*/; do
     skill=$(basename "$dir")
     if [ -d ~/.claude/skills/"$skill" ]; then
       \cp -rf "$dir" ~/.claude/skills/"$skill"
     fi
   done
   ```

7. **Update version, hooks, and infrastructure** :
   - Read `$FORGE_TMPDIR/VERSION` and write to `~/.claude/skills/forge/.forge-version`
   - Clear cache `~/.claude/skills/forge/.forge-update-cache` to force a fresh check on next startup
   - Run `forge-hooks-setup.sh` to install/update FORGE hooks (idempotent) :
     - `bash-interceptor.js` -- PreToolUse[Bash]: blocks dangerous commands + token optimization
     - `token-saver.sh` -- execution script for output filtering
     - `forge-update-check.sh` -- SessionStart: update notifications
     - `forge-memory-sync.sh` -- Stop: vector memory sync at end of session
     - `statusline.sh` -- Status line: persistent FORGE indicator in terminal bar
   - Remove deprecated hooks (`command-validator.js`, `output-filter.js`, `forge-auto-router.js`)
   - Patch `~/.claude/settings.json` with hooks, permissions, and statusLine config (idempotent)
   ```bash
   \cp -f "$FORGE_TMPDIR/VERSION" ~/.claude/skills/forge/.forge-version
   rm -f ~/.claude/skills/forge/.forge-update-cache
   bash ~/.claude/skills/forge/scripts/forge-hooks-setup.sh
   ```

8. **Suggest Business Pack** (if not installed and no `--pack` argument) :
   - Check if any skill from `$FORGE_TMPDIR/packs/business/` exists in `~/.claude/skills/`
   - If none installed, display a one-time suggestion:
     ```
     Tip: FORGE Business Pack available (marketing, SEO, legal, security, strategy).
     Install with: /forge-update --pack business
     ```

9. **Update ~/.claude/CLAUDE.md** :
   - Compare `$FORGE_TMPDIR/templates/claude-md-forge-section.md` with the current FORGE block in `~/.claude/CLAUDE.md` (content between `<!-- FORGE:BEGIN -->` and `<!-- FORGE:END -->`)
   - If markers don't exist in `~/.claude/CLAUDE.md` : run `bash "$FORGE_TMPDIR/scripts/inject-claude-md.sh"` (will ask user confirmation)
   - If markers exist and content is identical : display "CLAUDE.md FORGE section is up to date" and skip
   - If markers exist and content differs :
     - Display diff between current block and template
     - Ask confirmation before replacing
     - If confirmed : run `bash "$FORGE_TMPDIR/scripts/inject-claude-md.sh"`
     - If refused : skip

10. **Verify installation** :
    - Confirmer que `~/.claude/skills/forge/SKILL.md` existe toujours
    - Compter le nombre de skills installés (core + pack si installé)

11. **Clean up** :
    ```bash
    rm -rf "$FORGE_TMPDIR"
    ```

12. **Save memory** (if `.forge/` exists — ensures update history persists for version tracking and rollback reference):
    ```bash
    forge-memory log "FORGE updated: v{OLD} -> v{NEW}, {X} skills modified, {Y} new, business pack: {installed/not installed}" --agent update
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
