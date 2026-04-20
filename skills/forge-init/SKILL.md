---
name: forge-init
description: >
  Initialize FORGE in a project -- creates .forge/ structure, CLAUDE.md, detects tech stack.
---

# /forge-init -- FORGE Initialization

Initializes the FORGE framework in a new or existing project.

## Workflow

1. **Detect the context**:
   - If a path is provided as argument, initialize that directory
   - Otherwise, initialize the current directory
   - Check if FORGE is already initialized (`.forge/config.yml` exists)
   - If already initialized: still run Token Saver setup (step 8), then suggest `/forge-resume` for project work

2. **Detect the tech stack**:
   - Language: TypeScript, Python, Go, Rust, etc. (via tsconfig.json, pyproject.toml, go.mod, Cargo.toml)
   - Project type: web-app, api, mobile, library, cli (via package.json, framework markers)
   - Framework: React, Next.js, Angular, Express, Django, FastAPI, Expo, etc.
   - Package manager: pnpm, npm, yarn, pip, cargo, go modules

3. **Create the FORGE structure**:

   ```
   .forge/
     config.yml              # Main configuration (generated)
     sprint-status.yaml      # Sprint tracking (empty)
     memory/
       MEMORY.md             # Project memory (decisions, state)
       sessions/             # Daily session logs
     wiki/                   # Knowledge wiki (Obsidian-compatible)
       CLAUDE.md             # Vault schema contract
       index.md              # Wiki home
       log.md                # Ingestion journal
       raw/                  # Raw sources (stories, bugs, notes)
       wiki/                 # Compiled pages
         concepts/           # Components/features
         stories/            # Story pages with wikilinks
         bugs/               # Bug pages (root cause + fix)
         decisions/          # ADR pages
         synthesis/          # Archived query answers
     templates/              # Artifact templates
       prd.md
       architecture.md
       story.md
       ux-design.md
       sprint-status.yaml
     workflows/              # Workflow definitions
       quick.yaml
       standard.yaml
       enterprise.yaml
   docs/
     stories/                # Stories directory
     adrs/                   # Architecture Decision Records
   references/
     agents/                 # Agent personas (copied from FORGE repo)
   ```

   The wiki vault (`.forge/wiki/`) is created automatically from bundled templates at `~/.claude/skills/forge/templates/wiki/`. It is versioned (committed with the project) and works with or without Obsidian installed. If Obsidian is detected on the machine, a hint is displayed suggesting to open `.forge/wiki/` as a vault for graph view.

4. **Generate `.forge/config.yml`**:
   - Pre-fill `project.name`, `project.type`, `project.language` based on detection
   - Ask the user to confirm or adjust
   - Offer the scale choice: quick, standard, enterprise

5. **Generate `CLAUDE.md`**:
   - If the file does not exist, create it with:
     - Detected project name and type
     - List of available FORGE commands
     - Conventions (commits, tests, branches)
     - Architecture section (placeholder -> to be filled by `/forge-architect`)
   - If the file already exists, offer to add the FORGE Commands section

6. **Configure `.gitignore`**:
   - Add FORGE entries (.forge/secrets/, .forge/audit.log, .env, etc.)

7. **Verify FORGE installation**:
   - Confirm hub exists at `~/.claude/skills/forge/SKILL.md`
   - Confirm satellites exist at `~/.forge/skills/` (installed globally by `install.sh`)
   - If missing, suggest running `install.sh` or `/forge-update`
   - Do NOT copy skills into the project directory -- FORGE skills are global

8. **Install Token Saver** (global, idempotent):
   - Creates `~/.claude/hooks/bash-interceptor.js` (unified PreToolUse hook: blocks dangerous commands + rewrites verbose output)
   - Creates `~/.claude/hooks/token-saver.sh` (wrapper that executes commands and filters output)
   - Removes legacy hooks (`command-validator.js`, `output-filter.js`) if present
   - Patches `~/.claude/settings.json` to add the hook and permission
   - Covered commands: git, npm, pnpm, yarn, bun, pip, pytest, go, cargo, docker, make, mvn, gradle, dotnet, swift, tsc
   - Note: Additional FORGE hooks (update-check, memory-sync, statusline) are installed via `install.sh` or `/forge-update`

9. **Install forge-memory CLI** (global, idempotent):
   - Check if `forge-memory` is in PATH: `which forge-memory`
   - If NOT found, run the setup script:
     ```bash
     bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh
     ```
   - If the setup script does not exist, warn the user and skip memory steps
   - This installs the Python venv, sentence-transformers model, and symlinks `forge-memory` to `~/.local/bin/`

10. **Save memory** (ensures initialization context persists for all subsequent agents):
   ```bash
   forge-memory log "Projet initialisé : {LANGUAGE}/{FRAMEWORK}, type {PROJECT_TYPE}, track {SCALE}" --agent init
   forge-memory sync
   ```

11. **Display the summary**:
   - Detected stack
   - Created files
   - Recommended next steps:
     - `/forge-plan` to start planning
     - `/forge-status` to view the project state

## Notes

- The shell script `forge-init.sh` (in `.claude/skills/forge/`) contains the basic initialization logic
- This skill extends the script with advanced detection and Claude interactivity
- Never overwrite an existing `CLAUDE.md` without asking for confirmation
- Never overwrite an existing `.forge/config.yml` -> suggest `/forge-resume` instead

Flow progression is managed by the FORGE hub.
