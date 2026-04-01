# forge:ship -- Prepare a FORGE release

Run the ship script, analyze README content, then create the release branch and PR.

## Instructions

You are executing the `/forge:ship` release preparation command. Follow these steps exactly:

### Step 1: Run the ship script (pre-checks + file updates)

Run `bash scripts/forge-ship.sh $ARGUMENTS` and capture the output. The script will:
- Verify pre-conditions (clean tree, on main, gh auth)
- Calculate the new version from Conventional Commits
- Update VERSION, CHANGELOG.md, and README.md (badge + Latest line)

If the script fails, show the error and stop.

### Step 2: Analyze README content

Read `README.md` and the new CHANGELOG entry. Check whether the README still accurately reflects the project:

1. **Skills count**: Does the badge and text match the actual number of skills in `skills/` and `packs/business/`?
2. **Command tables**: Are all commands listed? Check `skills/` directory names against the Pipeline and Tools tables.
3. **Feature descriptions**: Do they match current capabilities?
4. **New additions**: Does the CHANGELOG entry mention anything that should be reflected in README (new skills, removed features, changed behavior)?

Present your findings:
- `[OK]` for items that are accurate
- `[UPDATE]` for items that need changes, with the specific edit proposed

### Step 3: Get user confirmation

Show the summary of all changes (script updates + your README proposals) and ask:
> "Confirmer les modifications et creer la PR ? (oui/non)"

If the user wants changes, make them. If they confirm, proceed.

### Step 4: Create release branch and PR

Run `bash scripts/forge-ship.sh $ARGUMENTS finalize` to create the branch, commit, push, and open the PR.

Show the PR URL and remind: "Prochaine etape : merger la PR, puis lancer `/forge:release`"
