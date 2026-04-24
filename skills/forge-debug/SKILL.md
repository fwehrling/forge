---
name: forge-debug
description: >
  FORGE Debug Agent -- systematic 4-phase root cause investigation (investigate, analyze, hypothesize, fix) for bugs with UNKNOWN cause. Use whenever the user reports non-reproducible bugs, flaky tests, intermittent failures, mysterious 500s, OOM kills, race conditions, and asks explicitly for 'root cause', 'investigation', 'enquete', 'pas un fix bidon', 'understand WHY', 'hypothese unique testee'. Not for quick fixes / hotfixes / one-liners / typos where the cause is already identified -- those go to forge-quick-spec.
---

# FORGE Debug Agent -- Root Cause Investigation

Core principle: **no fixes without root cause understanding**. Symptom fixes create more bugs. This skill is a scaffold, not a script -- scale the effort to the bug.

## How to use this scaffold

For a **trivial bug** (cause becomes obvious after reading the stack trace or the recent diff): jump straight to the fix. Don't drag the user through 4 phases to patch a typo.

For a **complex or non-reproducible bug** (flaky test, mysterious 500, OOM, race condition): work through the phases below. Skip any step that doesn't fit the bug; state why.

## Phase 1 -- Investigate

Goal: build a mental model of what's happening.

- Read the error/stack trace completely. Note file, line, error code.
- Try to reproduce. If reproducible, capture the exact steps. If not, gather more data before guessing.
- Check recent changes: `git diff`, new deps, config diffs.
- On multi-component systems (API -> service -> db): identify which boundary the bad data crosses. Log or instrument at component boundaries when the cause is unclear.
- Trace bad values backward to their source. Fix at the source, not the symptom.

## Phase 2 -- Pattern match

Goal: compare to known-good.

- Find similar working code in the same codebase.
- List concrete differences between working and broken.
- Check env, config, dependencies the broken path needs.

Skip this phase if the root cause is already obvious from Phase 1.

## Phase 3 -- Hypothesis

- Write one hypothesis: "I think X is the root cause because Y."
- Test with the smallest possible change, one variable at a time.
- If it works -> Phase 4. If not -> new hypothesis. Don't stack fixes on top of failed ones.

## Phase 4 -- Fix

- Write a failing test that captures the bug (if the context is testable).
- Implement the smallest fix that addresses the root cause.
- Verify the fix and that nothing else broke.
- **Stop after 3 failed fixes.** If each fix reveals new coupling, the architecture is the real problem -- surface that to the user, don't keep patching.

## Defense-in-depth (optional)

For bugs caused by invalid data, consider validating at multiple layers (entry point, business logic, environment guard) to make the class of bug impossible, not just this instance. Apply when the risk justifies the extra layers.

## Flaky tests -- condition-based waiting

Replace arbitrary delays with condition-based waits: `waitFor(() => events.find(e => e.type === 'DONE'))`, `waitFor(() => state === 'ready')`, `waitFor(() => fileExists(path))`.

## Handoff

Once the root cause is confirmed, report findings to the user.

If a fix was validated and `.forge/wiki/` exists:
- Assign a `BUG-XXX` ID (next available in `.forge/wiki/wiki/bugs/`, or reuse an existing one).
- Read `~/.forge/skills/forge-wiki/SKILL.md`, execute mode `ingest` with `source=bug:BUG-XXX`.
- Skip silently if only the root cause was identified (no fix), or if `.forge/wiki/` doesn't exist.

Flow progression is managed by the FORGE hub.
