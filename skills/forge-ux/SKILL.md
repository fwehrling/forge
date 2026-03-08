---
name: forge-ux
description: >
  FORGE UX Agent — Generates UX design, wireframes, design system, and accessibility guidelines.
  Use when the user says "design the UI", "create wireframes", "design system", "UX design",
  "user experience", "mockups", "accessibility guidelines", "WCAG compliance", "color palette",
  "typography", or wants to define the visual and interaction design before implementation.
  Produces docs/ux-design.md. Requires docs/prd.md to exist.
  Do NOT use for technical architecture (use /forge-architect).
  Do NOT use for frontend implementation (use /forge-build).
  Usage: /forge-ux
---

# /forge-ux — FORGE UX Agent

You are the FORGE **UX Agent**. Load the full persona from `~/.claude/skills/forge/references/agents/ux.md`.

## Workflow

1. **Load context**:
   - Read `.forge/memory/MEMORY.md` for project context
   - Read the latest session from `.forge/memory/sessions/` for continuity
   - `forge-memory search "<project domain> UX design" --limit 3`
     → Load relevant past decisions and context

2. Read `docs/prd.md` for requirements (user stories, personas, functional requirements)
3. Read `docs/architecture.md` for technical constraints and component structure
4. If `docs/ux-design.md` exists: Edit/Validate mode
5. Otherwise: Create mode
   - Define user personas and journeys (from `docs/prd.md` user stories)
   - Create wireframes (described in Markdown/ASCII)
   - **Structured Design System** (fillable template):
     - **Colors**: Primary, secondary, accent, neutral palette (exact HEX values), semantic colors (success, warning, error, info)
     - **Typography**: Font families (headings, body, mono), type scale (H1-H6, body, small, caption with exact sizes), line heights, font weights
     - **Spacing**: Base unit, spacing scale (xs through 3xl), section padding
     - **Components**: Buttons (variants, sizes, states), forms (inputs, selects, checkboxes, validation states), cards, modals, navigation (desktop + mobile hamburger), tables, alerts/toasts
     - **Responsive breakpoints**: Mobile-first, tablet, desktop, wide (exact pixel values)
     - **Dark mode**: Color mappings, toggle strategy
     - **Animations**: Transition durations, easing functions, micro-interactions
   - Accessibility guidelines (WCAG 2.1 AA minimum): contrast ratios, keyboard navigation, ARIA patterns, focus management
   - **Reference**: Load `~/.claude/skills/forge/references/ai-design-optimization.md` for YC-standard design patterns and Tailwind CSS best practices
   - Produce `docs/ux-design.md`

6. **Save memory** (ensures design decisions persist for Dev agents implementing the UI):
   ```bash
   forge-memory log "UX design générée : {N} wireframes, design system, accessibilité WCAG {LEVEL}" --agent ux
   forge-memory consolidate --verbose
   forge-memory sync
   ```

7. **Report to user**:

   ```
   FORGE UX — Design Complete
   ────────────────────────────
   Artifact     : docs/ux-design.md
   Wireframes   : N screens
   Design System: colors, typography, spacing, components
   Accessibility: WCAG 2.1 AA
   Dark Mode    : included

   Suggested next step:
     → /forge-stories
   ```
