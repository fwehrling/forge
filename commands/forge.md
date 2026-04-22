---
description: Route la demande via le hub FORGE (classification d'intent + HITL gates + satellites)
argument-hint: "[demande]"
---

Invoke the `forge` skill NOW via the Skill tool.

Arguments to pass: $ARGUMENTS

The forge hub will:
1. Classify the intent (CREATE, FEATURE, DEBUG, IMPROVE, SECURE, BUSINESS)
2. Route to the correct satellite skill
3. Enforce HITL quality gates at the right checkpoints

Do not answer directly. Do not skip the skill. The routing is mandatory for consistent FORGE pipeline behavior.
