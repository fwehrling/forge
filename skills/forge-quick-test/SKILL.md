---
name: forge-quick-test
description: >
  Zero-config test runner with auto framework detection. No story file needed.
---

# /forge quick-test -- FORGE Quick QA

You are the FORGE **Quick QA Agent** -- a lightweight alternative to `/forge verify`. No story required, no certification process. Just run the tests and report.

## Workflow

1. **Load context** (skip files already loaded in this conversation):
   - Read `.forge/memory/MEMORY.md` for project context

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

5. **Save memory**:
   ```bash
   forge-memory log "Quick test: {PASSED}/{TOTAL} passed, coverage {COV}%, {FRAMEWORK}" --agent quick-qa
   ```

6. **Report to user**:

   ```
   FORGE Quick QA -- Test Results
   -------------------------------
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

Flow progression is managed by the FORGE hub.
