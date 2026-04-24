---
name: forge-party
description: >
  Multi-perspective analysis with 2-3 lightweight subagents (Task tool).
  Brainstorm, debate, compare approaches.
paths:
  - ".forge/**"
---

# /forge party -- Multi-perspective analysis

Coordinate 2-3 perspectives on a topic via Task tool subagents, then synthesize. This skill exists for cases where real independence between viewpoints helps (adversarial thinking, blind spots) -- for quick back-of-envelope analysis, you don't need it.

## Perspectives available

Pick the 2-3 that actually matter for the topic. Don't invoke unused ones:

- **Architect** -- system design, scalability, tech stack (`agents/architect.md`)
- **PM** -- user value, priorities, scope (`agents/pm.md`)
- **Security** -- threats, compliance, attack surface (`agents/security.md`)
- **Dev** -- feasibility, effort, patterns (`agents/dev.md`)
- **QA** -- testability, quality risk (`agents/qa.md`)
- **Reviewer** -- adversarial, risks, alternatives (`agents/reviewer.md`)

## Workflow

1. **Load context** (skip if already in context):
   - `.forge/memory/MEMORY.md`
   - `forge-memory search "<topic>" --limit 3` if relevant

2. **Pick perspectives**: choose the 2-3 angles most relevant to the question. You may go to 4 if the topic genuinely cuts across that many domains -- or to 2 if one additional angle would be noise.

3. **Launch subagents in parallel** via Task tool. Each brief should include: the topic, the specific angle to take, any relevant files to read, and a request for concrete observations + risks + recommendation (not a fixed template -- let the agent structure its answer).

4. **Synthesize**. The output format should match the question:
   - If convergence matters: show consensus vs divergence clearly.
   - If a decision is needed: recommend one approach with reasoning.
   - If the goal is brainstorming: present distinct takes without forcing a synthesis.

5. **Save memory** when the analysis produced a decision worth remembering:
   ```bash
   forge-memory log "Party: {TOPIC} -> {RECOMMENDATION}" --agent orchestrator
   ```

Flow progression is managed by the FORGE hub.
