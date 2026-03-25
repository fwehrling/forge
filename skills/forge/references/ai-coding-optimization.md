# AI Coding Agent -- Best Practices Reference

Actionable patterns for AI-assisted code generation. Tool-agnostic.

---

## 1. Code Organization

- **Single responsibility per file**: one module, one concern
- **Consistent naming conventions**: document them in project rules so the agent follows them
- **Small, focused functions**: max ~30 lines; easier for the agent to generate and review
- **Explicit imports**: no wildcard imports; helps the agent trace dependencies
- **Directory structure mirrors domain**: group by feature, not by file type
- **Keep related code close**: co-locate components, tests, and types

## 2. Documentation for AI Consumption

- **Project context file** (e.g., `CLAUDE.md`, `prompt.txt`): naming conventions, architecture overview, key commands, error-handling approach, SDK examples
- **Inline comments for "why", not "what"**: the agent reads code; explain intent and non-obvious constraints
- **Type annotations everywhere**: TypeScript types, Python type hints, JSDoc -- they are the strongest signal for correct generation
- **Keep docs next to code**: a `README.md` per module beats a central wiki the agent cannot reach
- **Use structured formats**: markdown headings, bullet lists, tables -- agents parse these better than prose
- **Document edge cases explicitly**: boundary conditions, known limitations, expected error states

## 3. Error Handling

- **Fail fast, fail loud**: validate inputs at function entry; return early on invalid state
- **Typed errors over generic exceptions**: custom error classes or result types (`Result<T, E>`)
- **Never swallow errors silently**: always log or propagate; silent catches hide bugs from agent and human alike
- **Consistent error response shape**: in APIs, always return `{ error: string, code: string }` (or equivalent)
- **Wrap external calls**: isolate third-party API calls behind try/catch with context-rich error messages
- **Define fallback behavior**: retry, default value, or abort -- never leave failure handling ambiguous

## 4. Testing Patterns

- **Test file next to source**: `foo.ts` -> `foo.test.ts` in same directory
- **One assertion per test** (or one logical group): small tests are easier to generate and debug
- **Arrange-Act-Assert structure**: keep every test predictable
- **Name tests as behavior specs**: `should return 404 when user not found`
- **Mock external dependencies, not internal logic**: test real behavior, fake only I/O boundaries
- **Cover the sad path first**: error cases and edge cases catch more real bugs than happy-path tests
- **Regression test every bug fix**: one test per bug, named after the issue

## 5. Prompt & Context Principles

- **Be specific**: constraints, desired output format, language version, libraries allowed
- **Break down complex tasks**: one prompt per logical step; chain results
- **Provide examples**: a single input/output example beats a paragraph of explanation
- **State what NOT to do**: negative constraints reduce hallucinations ("do not use external libraries", "do not modify existing tests")
- **Request step-by-step reasoning** for algorithmic or multi-file tasks
- **Iterate, don't patch**: if output is fundamentally wrong, re-prompt with better context rather than fixing inline

## 6. Key Principles (Quick Reference)

| Principle | Rule of thumb |
|---|---|
| DRY | Extract when you repeat 2+ times |
| KISS | Simplest solution that works; no premature abstraction |
| YAGNI | Do not build features the spec does not require |
| Separation of concerns | I/O at edges, pure logic in the middle |
| Explicit over implicit | No magic globals, hidden state, or side effects in constructors |
| Immutability by default | Mutate only when performance requires it |
| Fail fast | Validate early, surface errors immediately |
| Minimal surface area | Expose only what consumers need; keep internals private |
| Conventional commits | `feat:`, `fix:`, `refactor:`, `test:`, `docs:` -- lowercase after prefix |
| Version control discipline | Commit often, small changesets, meaningful messages |
