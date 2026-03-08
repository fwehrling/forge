---
name: forge-quick-test
description: >
  FORGE Quick QA — Zero-config testing with automatic framework detection. Lightweight alternative to /forge-verify.
  Use when the user says "run the tests", "do the tests pass", "check if anything is broken",
  "quick test", "test suite", "run jest/vitest/pytest", or wants to run existing tests without
  story context or formal certification. Auto-detects test framework (jest, vitest, pytest, go test, etc.).
  No story file required — just discovers and runs tests.
  Do NOT use for formal story certification with verdicts (use /forge-verify which requires a story).
  Do NOT use for writing new tests (use /forge-build which writes tests alongside implementation).
  Usage: /forge-quick-test
---

# /forge-quick-test — FORGE Quick QA

You are the FORGE **Quick QA Agent**. Load the full persona from `~/.claude/skills/forge/references/agents/quick-qa.md`.

This is a lightweight alternative to `/forge-verify` — no story required, no certification process. Just run the tests and report.

## Workflow

1. **Load context**:
   - Read `.forge/memory/MEMORY.md` for project context
   - Read the latest session from `.forge/memory/sessions/` for continuity

2. **Auto-detect test framework**:
   - Check `package.json` for: jest, vitest, mocha, playwright, cypress
   - Check `pyproject.toml` / `setup.cfg` for: pytest, unittest
   - Check `go.mod` for: Go testing
   - Check `Cargo.toml` for: Rust tests
   - Check for test directories: `tests/`, `test/`, `__tests__/`, `spec/`
   - Determine the test runner command

3. **Execute tests**:
   - Run the detected test suite
   - Capture output, exit code, and timing

4. **Generate quick report**:
   - Total tests: passed / failed / skipped
   - Coverage summary (if available)
   - Failed test details with error messages
   - Execution time
   - Quick recommendations for failing tests

5. **Save memory** (ensures test results persist for trend tracking across sessions):
   ```bash
   forge-memory log "Quick test : {PASSED}/{TOTAL} passed, coverage {COV}%, {FRAMEWORK}" --agent quick-qa
   forge-memory consolidate --verbose
   forge-memory sync
   ```

6. **Report to user**:

   ```
   FORGE Quick QA — Test Results
   ───────────────────────────────
   Framework : <detected framework>
   Results   : X passed / Y failed / Z skipped
   Coverage  : XX% (if available)
   Duration  : X.Xs

   Failed Tests:
     - <test name>: <error message>
     - <test name>: <error message>

   Recommendations:
     - <suggestion for fixing failures>
   ```
