---
name: forge-update
description: >
  Updates FORGE skills from GitHub. Supports --pack business.
---

# /forge-update -- FORGE Updater

## Arguments

- No arguments: update core FORGE skills only
- `--pack business`: also install/update the Business Pack (marketing, SEO, legal, security, strategy agents)
- `--pack business --only`: install/update only the Business Pack without updating core skills
- `--full`: when retrofitting the wiki vault on a legacy project, also ingest all existing stories/bugs/ADRs found in the project (default behavior is lazy -- only bootstrap the empty vault)

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
   > **Important**: use `FORGE_TMPDIR`, NOT `TMPDIR` -- `TMPDIR` is a macOS system variable (`/var/folders/...`) and would cause path errors.

3. **Compare skills** :
   - For the hub: compare `$FORGE_TMPDIR/skills/forge/` with `~/.claude/skills/forge/`
   - For each satellite `$FORGE_TMPDIR/skills/forge-*/`: compare with `~/.forge/skills/<skill>/`
   - Classify into 3 categories: **modified**, **new**, **removed**
   - Display a clear summary of detected changes

4. **Display change summary** :
   - List modified skills with affected files
   - List new skills
   - List removed skills (present locally but absent from repo)
   - If no changes, display "FORGE is already up to date" and stop

5. **Migrate old layout and copy updated files** :

   Hub-only architecture: only `forge/` goes to `~/.claude/skills/`, all satellites go to `~/.forge/skills/`.

   ```bash
   # Create ~/.forge/skills/ if missing (v1 installations)
   mkdir -p ~/.forge/skills

   # Migrate: remove old forge-* satellites from ~/.claude/skills/ (v1 layout)
   for old_sat in ~/.claude/skills/forge-*/; do
     [ -d "$old_sat" ] || continue
     skill=$(basename "$old_sat")
     rm -rf "$old_sat"
     echo "Migrated from ~/.claude/skills/: $skill"
   done

   # Copy hub to ~/.claude/skills/
   # Use \cp to bypass macOS cp -i alias that blocks non-interactive overwrites.
   rm -rf ~/.claude/skills/forge
   \cp -rf "$FORGE_TMPDIR/skills/forge/" ~/.claude/skills/forge/

   # Copy satellites to ~/.forge/skills/
   for dir in "$FORGE_TMPDIR/skills/"forge-*/; do
     [ -d "$dir" ] || continue
     skill=$(basename "$dir")
     rm -rf ~/.forge/skills/"$skill"
     \cp -rf "$dir" ~/.forge/skills/"$skill"
   done
   ```
   - **NEVER** use `rsync --delete`, `rsync -a --delete`, or any destructive sync
   - Only FORGE skills (`forge` and `forge-*`) are managed by this updater
   - Non-FORGE skills in `~/.claude/skills/` MUST be preserved (they belong to the user)
   - The repo `README.md` stays on GitHub only (not copied into skills)
   - **Remove deprecated skills** from both locations:
   ```bash
   REMOVED_SKILLS="forge-deploy"
   for skill in $REMOVED_SKILLS; do
     for loc in ~/.claude/skills/"$skill" ~/.forge/skills/"$skill"; do
       if [ -d "$loc" ]; then
         rm -rf "$loc"
         echo "Removed deprecated: $skill"
       fi
     done
   done
   ```

6. **Install packs** (if `--pack` argument provided) :
   - Read `$FORGE_TMPDIR/packs.yaml` to get the list of skills in the requested pack
   - For each skill in the pack:
     - Compare `$FORGE_TMPDIR/packs/<pack>/<skill>/` with `~/.forge/skills/<skill>/`
     - Copy if new or modified
   ```bash
   # Example for --pack business:
   for dir in "$FORGE_TMPDIR/packs/business/"forge-*/; do
     [ -d "$dir" ] || continue
     skill=$(basename "$dir")
     rm -rf ~/.forge/skills/"$skill"
     \cp -rf "$dir" ~/.forge/skills/"$skill"
   done
   ```
   - If `--only` flag is set, skip core skills update (step 5) and jump directly here
   - Display which pack skills were installed/updated
   - If no `--pack` argument and business pack skills already exist locally, still update them
     (because they were previously installed and should stay in sync)
   ```bash
   # Auto-detect previously installed pack skills
   for dir in "$FORGE_TMPDIR/packs/business/"forge-*/; do
     [ -d "$dir" ] || continue
     skill=$(basename "$dir")
     if [ -d ~/.forge/skills/"$skill" ]; then
       rm -rf ~/.forge/skills/"$skill"
       \cp -rf "$dir" ~/.forge/skills/"$skill"
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

8. **Retrofit wiki vault** (if CWD is a FORGE project without `.forge/wiki/`) :
   - If `.forge/config.yml` exists but `.forge/wiki/` is missing, the project predates the wiki feature
   - Bootstrap the vault structure locally (mimicking `forge-init.sh`) :
     ```bash
     PROJECT_PATH="$(pwd)"
     WIKI_TEMPLATE_DIR="${HOME}/.claude/skills/forge/templates/wiki"
     PROJECT_NAME_RESOLVED="$(basename "$PROJECT_PATH")"
     WIKI_DATE="$(date -Iseconds)"

     if [ -f "${PROJECT_PATH}/.forge/config.yml" ] \
        && [ ! -d "${PROJECT_PATH}/.forge/wiki" ] \
        && [ -d "${WIKI_TEMPLATE_DIR}" ]; then
       mkdir -p "${PROJECT_PATH}/.forge/wiki/raw/stories"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/raw/bugs"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/raw/notes"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/wiki/concepts"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/wiki/stories"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/wiki/bugs"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/wiki/decisions"
       mkdir -p "${PROJECT_PATH}/.forge/wiki/wiki/synthesis"
       cp "${WIKI_TEMPLATE_DIR}/CLAUDE.md" "${PROJECT_PATH}/.forge/wiki/CLAUDE.md"
       sed -e "s|{{DATE}}|${WIKI_DATE}|g" \
           -e "s|{{PROJECT_NAME}}|${PROJECT_NAME_RESOLVED}|g" \
           "${WIKI_TEMPLATE_DIR}/index.md" > "${PROJECT_PATH}/.forge/wiki/index.md"
       sed -e "s|{{DATE}}|${WIKI_DATE}|g" \
           -e "s|{{PROJECT_NAME}}|${PROJECT_NAME_RESOLVED}|g" \
           "${WIKI_TEMPLATE_DIR}/log.md" > "${PROJECT_PATH}/.forge/wiki/log.md"
       echo "Wiki vault created at .forge/wiki/"
     fi
     ```
   - **Lazy by default**: the vault is created empty. Stories/bugs will be ingested as they happen (via hooks in forge-verify, /forge ship, forge-debug).
   - **If `--full` flag is set**: after bootstrap, load `forge-wiki` and invoke mode `ingest` once per existing story in `docs/stories/*.md`, once per ADR in `docs/adrs/*.md`. Warn the user this may consume significant tokens.
   - Skip silently if not in a FORGE project, or if `.forge/wiki/` already exists.

9. **Suggest Business Pack** (if not installed and no `--pack` argument) :
   - Check if any skill from `$FORGE_TMPDIR/packs/business/` exists in `~/.forge/skills/`
   - If none installed, display a one-time suggestion:
     ```
     Tip: FORGE Business Pack available (marketing, SEO, legal, security, strategy).
     Install with: /forge-update --pack business
     ```

10. **Update ~/.claude/CLAUDE.md** :
   - Compare `$FORGE_TMPDIR/templates/claude-md-forge-section.md` with the current FORGE block in `~/.claude/CLAUDE.md` (content between `<!-- FORGE:BEGIN -->` and `<!-- FORGE:END -->`)
   - If markers don't exist in `~/.claude/CLAUDE.md` : run `bash "$FORGE_TMPDIR/scripts/inject-claude-md.sh"` (will ask user confirmation)
   - If markers exist and content is identical : display "CLAUDE.md FORGE section is up to date" and skip
   - If markers exist and content differs :
     - Display diff between current block and template
     - Ask confirmation before replacing
     - If confirmed : run `bash "$FORGE_TMPDIR/scripts/inject-claude-md.sh"`
     - If refused : skip

11. **Verify installation** :
    - Confirmer que `~/.claude/skills/forge/SKILL.md` existe (hub)
    - Confirmer que `~/.forge/skills/` contient les satellites
    - Vérifier qu'aucun `forge-*` ne reste dans `~/.claude/skills/` (migration complète)
    - Compter le nombre de skills installés (1 hub + satellites + pack si installé)

12. **Clean up** :
    ```bash
    rm -rf "$FORGE_TMPDIR"
    ```

13. **Save memory** (if `.forge/` exists -- ensures update history persists for version tracking and rollback reference):
    ```bash
    forge-memory log "FORGE updated: v{OLD} -> v{NEW}, {X} skills modified, {Y} new, business pack: {installed/not installed}" --agent update
    forge-memory consolidate --verbose
    forge-memory sync
    ```

14. **Display results** :

    ```
    FORGE Update -- Complete
    -------------------------
    Hub     : ~/.claude/skills/forge/
    Sats    : ~/.forge/skills/ (X updated, Y new)
    Pack    : Business Pack [installed / not installed]
              (Z skills updated)
    Total   : N skills installed
    Version : vX.Y.Z
    Cleanup : M old satellites removed from ~/.claude/skills/

    Tip: Install Business Pack with /forge-update --pack business
    ```

Flow progression is managed by the FORGE hub.
