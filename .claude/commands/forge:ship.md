# forge:ship -- Tag and deploy

Run `bash .claude/scripts/forge-ship.sh` and show the output.

The script handles everything automatically:
1. Verifies we're on main with a release commit
2. Creates annotated tag vX.Y.Z
3. Pushes the tag to trigger deployment

Do NOT ask for confirmation. Do NOT show warnings. Just run the script.
