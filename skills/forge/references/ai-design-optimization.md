# UI/UX Design Reference for Dev Agents

## Core UX Principles

- **Clarity first**: every screen has one obvious primary action
- **Visual hierarchy**: size, weight, color, spacing guide the eye
- **Consistency**: same action = same appearance everywhere
- **Feedback**: every action gets an immediate visible response (loading, success, error)
- **Error prevention**: disable invalid actions, sensible defaults, confirm destructive ops
- **Progressive disclosure**: show only what is needed now; reveal details on demand
- **Minimal input**: autofill, smart defaults, inline validation

## Tailwind CSS Patterns

### Spacing
- 4px grid: `p-1`(4), `p-2`(8), `p-4`(16), `p-6`(24), `p-8`(32)
- Gaps: `gap-2` fields, `gap-4` grids, `gap-6` sections
- Container: `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8`

### Typography
- Scale: `text-sm` labels, `text-base` body, `text-lg`/`text-xl`/`text-2xl` headings
- Weights: `font-normal` body, `font-medium` labels, `font-semibold` headings
- `leading-relaxed` body, `leading-tight` headings, `truncate` or `line-clamp-2`

### Colors
- Semantic tokens in config: `primary`, `secondary`, `accent`, `destructive`, `muted`
- Surfaces: `bg-white dark:bg-gray-900`, `bg-gray-50 dark:bg-gray-800` (raised)
- Text: `text-gray-900 dark:text-gray-100` primary, `text-gray-500 dark:text-gray-400` secondary
- Borders: `border-gray-200 dark:border-gray-700`. Never use raw hex -- use tokens

### Responsive
- Mobile-first: base = mobile, then `sm:`, `md:`, `lg:`, `xl:`
- Grid: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6`
- Stack to row: `flex flex-col sm:flex-row`. Touch targets: min `h-10 w-10`

## Component Patterns

### Buttons
- Base: `inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-medium focus-visible:ring-2 disabled:opacity-50 transition-colors`
- Primary: `bg-primary text-white hover:bg-primary/90`
- Outline: `border border-input bg-transparent hover:bg-accent`
- Destructive: `bg-destructive text-white hover:bg-destructive/90`
- Ghost: `hover:bg-accent hover:text-accent-foreground`

### Forms
- Label+input: `flex flex-col gap-1.5`, spacing: `space-y-4`
- Input: `w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:ring-2`
- Error: `border-destructive` + `<p class="text-sm text-destructive">`

### Cards
- Container: `rounded-lg border bg-card p-6 shadow-sm`
- Title `text-lg font-semibold`, desc `mt-2 text-sm text-muted-foreground`, actions `mt-4 flex gap-2`

### Modals
- Overlay: `fixed inset-0 z-50 bg-black/50 backdrop-blur-sm`
- Panel: `fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2 rounded-lg bg-background p-6 shadow-lg w-full max-w-md`
- Trap focus, close on Escape

### Navigation
- Header: `sticky top-0 z-40 border-b bg-background/95 backdrop-blur`
- Links: `text-sm font-medium text-muted-foreground hover:text-foreground transition-colors`
- Active: `text-foreground font-semibold` or `border-b-2 border-primary`

## Accessibility (WCAG 2.1 AA)

- Contrast >= 4.5:1 text, >= 3:1 large text/UI
- All `<img>` have `alt` (or `alt=""` decorative)
- Full keyboard nav, visible `focus-visible:ring-2` on all interactives
- Labels via `htmlFor`/`id`, errors via `aria-describedby`
- ARIA on custom widgets: `role="dialog"`, `aria-modal`, `aria-expanded`
- Skip-to-content link, no color-only info, respect `prefers-reduced-motion`

## Dark Mode

- Class-based: `.dark` on `<html>`, use `dark:` variant
- Color pairs via CSS vars: `:root { --bg: 0 0% 100%; }` / `.dark { --bg: 0 0% 3.9%; }`
- Shadows: `shadow-sm dark:shadow-none` or `ring-1 ring-white/10`
- Images: `dark:brightness-90` or swap assets

## Animation

- Hovers: `transition-colors duration-150`
- Scale: `transition-transform duration-200`
- Entrance: `animate-in fade-in slide-in-from-bottom-2 duration-200`
- Loading: `animate-spin` (spinner), `animate-pulse` (skeleton)
- Durations: 150-300ms UI, 300-500ms page transitions
- Always: `motion-reduce:transition-none motion-reduce:animate-none`
