---
name: forge-debug
description: >
  Debug Agent -- systematic root cause investigation (4 phases: investigate, analyze,
  hypothesize, fix). Bugs, test failures, flaky tests, unexpected behavior.
paths:
  - ".forge/**"
---

# FORGE Debug Agent — Systematic Root Cause Investigation

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes. Symptom fixes are failure.

## When to Use

Use for ANY technical issue where the cause is unknown:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues
- Flaky tests

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (systematic is faster than thrashing)

## The Four Phases

Complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**
   - Don't skip past errors or warnings
   - Read stack traces completely
   - Note line numbers, file paths, error codes

2. **Reproduce Consistently**
   - Can you trigger it reliably?
   - What are the exact steps?
   - If not reproducible, gather more data -- don't guess

3. **Check Recent Changes**
   - Git diff, recent commits
   - New dependencies, config changes
   - Environmental differences

4. **Gather Evidence in Multi-Component Systems**

   When the system has multiple components (API -> service -> database, CI -> build -> deploy):

   ```
   For EACH component boundary:
     - Log what data enters component
     - Log what data exits component
     - Verify environment/config propagation
     - Check state at each layer

   Run once to gather evidence showing WHERE it breaks
   THEN analyze evidence to identify failing component
   THEN investigate that specific component
   ```

5. **Trace Data Flow Backward**

   When the error is deep in the call stack:
   - Where does the bad value originate?
   - What called this with the bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

   Add instrumentation if needed:
   ```typescript
   const stack = new Error().stack;
   console.error('DEBUG operation:', {
     parameter,
     cwd: process.cwd(),
     stack,
   });
   ```

### Phase 2: Pattern Analysis

1. **Find Working Examples** -- Locate similar working code in the same codebase
2. **Compare Against References** -- Read reference implementations COMPLETELY, don't skim
3. **Identify Differences** -- List every difference between working and broken, however small
4. **Understand Dependencies** -- What components, settings, config, environment does this need?

### Phase 3: Hypothesis and Testing

1. **Form Single Hypothesis** -- "I think X is the root cause because Y" -- write it down
2. **Test Minimally** -- Make the SMALLEST possible change to test the hypothesis, one variable at a time
3. **Verify** -- Worked? -> Phase 4. Didn't work? -> Form NEW hypothesis. Don't stack fixes.

### Phase 4: Implementation

1. **Create Failing Test Case** -- Simplest possible reproduction, automated if possible
2. **Implement Single Fix** -- Address root cause, ONE change, no "while I'm here" improvements
3. **Verify Fix** -- Test passes? No other tests broken? Issue actually resolved?
4. **If Fix Doesn't Work** -- Count fixes attempted:
   - < 3: Return to Phase 1 with new information
   - >= 3: **STOP -- question the architecture** (see below)

### Phase 4.5: Architecture Question (3+ failed fixes)

**Pattern indicating architectural problem:**
- Each fix reveals new shared state/coupling/problems elsewhere
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

**STOP and question fundamentals:**
- Is this pattern fundamentally sound?
- Are we sticking with it through sheer inertia?
- Should we refactor architecture vs. continue fixing symptoms?

**Ask the user before attempting more fixes.** This is NOT a failed hypothesis -- this is a wrong architecture.

---

## Defense-in-Depth

When you fix a bug caused by invalid data, validate at EVERY layer data passes through:

| Layer | Purpose | Example |
|-------|---------|---------|
| Entry Point | Reject invalid input at API boundary | `if (!dir) throw new Error('dir required')` |
| Business Logic | Ensure data makes sense for this operation | Validate domain constraints |
| Environment Guard | Prevent dangerous operations in specific contexts | Refuse git init outside tmpdir in tests |
| Debug Instrumentation | Capture context for forensics | Stack trace logging before dangerous ops |

Single validation = "We fixed the bug." Multiple layers = "We made the bug impossible."

---

## Condition-Based Waiting (Flaky Tests)

When tests use arbitrary delays (`setTimeout`, `sleep`), replace with condition-based waiting:

```typescript
// Bad: guessing at timing
await new Promise(r => setTimeout(r, 50));

// Good: waiting for the actual condition
await waitFor(() => getResult() !== undefined);
```

| Scenario | Pattern |
|----------|---------|
| Wait for event | `waitFor(() => events.find(e => e.type === 'DONE'))` |
| Wait for state | `waitFor(() => machine.state === 'ready')` |
| Wait for file | `waitFor(() => fs.existsSync(path))` |

---

## Handoff to forge-quick-spec

Once root cause is identified and confirmed:

1. Summarize the root cause and evidence
2. Invoke `/forge-quick-spec` with the fix description
3. forge-quick-spec handles: spec, tests, implementation, commit

```
forge-debug (Phase 1-3)     →  forge-quick-spec (Phase 4)
├─ Root cause identified      ├─ Tests de regression
├─ Evidence gathered          ├─ Implementation du fix
├─ Hypothesis confirmed       ├─ Verification
└─ Fix strategy defined       └─ Commit
```

---

## Red Flags -- STOP and Return to Phase 1

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "One more fix attempt" (when already tried 2+)
- Proposing solutions before tracing data flow

**ALL of these mean: STOP. Return to Phase 1.**

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "I see the problem, let me fix it" | Seeing symptoms != understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question pattern. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Handoff** | Summarize root cause, invoke forge-quick-spec | Bug resolved, tests pass |

## Real-World Impact

- Systematic approach: 15-30 minutes to fix
- Random fixes approach: 2-3 hours of thrashing
- First-time fix rate: 95% vs 40%
- New bugs introduced: Near zero vs common
