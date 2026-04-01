# forge:release -- Tag and deploy a FORGE release

Create the git tag and push it to trigger VPS deployment.

## Instructions

You are executing the `/forge:release` command. This triggers a production deployment. Follow these steps exactly:

### Step 1: Show what will happen

Read the `VERSION` file and display:
- The version that will be tagged
- That this will push the tag to origin
- That this triggers a VPS deployment via GitHub webhook

### Step 2: Ask for explicit confirmation

Display:
> "ATTENTION : ceci va creer le tag vX.Y.Z et le pousser sur origin, ce qui declenchera le deploiement sur le VPS."
> "Confirmer ? (oui/non)"

Only proceed if the user explicitly confirms with "oui" or equivalent.

### Step 3: Run the release script

Run `bash scripts/forge-release.sh` and show the output.

If successful, display the tag and confirm deployment was triggered.
