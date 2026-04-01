# forge:release -- Prepare and push a release to GitHub (no deployment)

Run `bash .claude/scripts/forge-release.sh $ARGUMENTS` and show the output.

The script handles everything automatically:
1. Detects bump level from Conventional Commits (or accepts major/minor/patch override)
2. Updates VERSION, CHANGELOG.md, README.md (badge + latest line)
3. Commits, merges to main, pushes

No tag is created -- no deployment is triggered.

If the script succeeds, remind: "Prochaine etape : `/forge:ship` pour tagger et deployer."
If the script fails, show the error and stop.

Do NOT ask questions. Do NOT analyze README content. Just run the script.
