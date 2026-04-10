# Research: Budget Page Redesign

## Decision 1: Envelope Color Storage

**Decision**: Add a `color` string column (hex, e.g. `#10b981`) to
`budget_envelopes` with a default palette auto-assigned at creation time.

**Rationale**: The `budget_envelopes` table has no color field today. Storing
the color in the DB (rather than computing it from a hash of the name or id)
lets users change colors later without migrating data. A pre-defined 8-color
palette covers the expected envelope count; assignment wraps cyclically.

**Alternatives considered**:
- Hash-based color from envelope ID: simpler but not user-changeable, and
  color could conflict between envelopes with adjacent IDs.
- CSS custom property per envelope: no persistence across sessions.

---

## Decision 2: Month Navigation Strategy

**Decision**: Store the selected month as a `%Date{}` assign in the LiveView
socket. Navigation events (`prev_month`, `next_month`) shift the date using
`Date.shift/2` and reload budget data. No URL params needed for MVP.

**Rationale**: All data fetches are already scoped to a `%Date{}` passed to
`Budgeting.list_envelopes/1` and `Budgeting.to_be_budgeted/1`. Switching
months only requires updating the date assign and re-running those queries.
LiveView handles the diff patch; no full reload occurs.

**Alternatives considered**:
- URL query params (`?month=2026-03`): better bookmarking, but adds routing
  complexity not needed for a personal-use app.

---

## Decision 3: Monthly Income Source for Summary Cards

**Decision**: Promote `total_income/1` and `total_allocated/1` from private to
public in `Xactions.Budgeting`, and add `total_spent/1` as a new public
function summing per-envelope spending for the month.

**Rationale**: The summary cards need four values. These are simple query
extractions; no new logic is introduced. Promoting them keeps the LiveView
clean — it calls context functions rather than computing figures inline.

**Alternatives considered**:
- Compute income from envelope spending totals: incorrect — income is tracked
  separately via income-category transactions.
- Duplicate query inline in LiveView: violates context boundary.

---

## Decision 4: Inline Budget Editing Mechanism

**Decision**: Click-to-edit using a LiveView event that sets
`editing_envelope_id` as a socket assign, toggling between a display span and
a `<form>/<input>`. On blur or Enter, `set_allocation` fires the existing
event. No JavaScript required.

**Rationale**: The existing `set_allocation` event already handles persistence.
Only the UI changes: a click-activated input replaces the always-visible form.

**Alternatives considered**:
- LiveView JS `push` client-side toggle: adds unnecessary JS complexity for
  a state change that the server handles fine.

---

## Decision 5: DaisyUI — Retain Installation, Stop Using in New Code

**Decision**: DaisyUI remains installed (other pages depend on it), but **zero
DaisyUI classes are used in any new code for this feature**. The redesigned
`budget_live.ex` and `layouts.ex` navbar use raw Tailwind only. The DaisyUI
light/dark theme tokens in `app.css` are not modified.

**Rationale**: The Figma design uses no DaisyUI patterns. Fighting DaisyUI's
opinionated component styles (`btn`, `card`, `stats`, `badge`) to match the
design creates more work than just not using them. Modifying the DaisyUI theme
tokens would affect all existing pages, which are not in scope for this
feature. The clean separation is:

- New code (budget page + navbar) → raw Tailwind + inline styles for
  per-envelope colors
- Existing code (all other pages) → DaisyUI unchanged

A follow-on feature should migrate the remaining pages away from DaisyUI and
uninstall it, but that is out of scope here.

**Alternatives considered**:
- Override DaisyUI light theme tokens to match Figma: affects all pages,
  causes visual inconsistency during a partial migration.
- Remove DaisyUI now and rewrite all pages: correct long-term, but triples
  the scope of this feature.
- Keep using DaisyUI on the budget page with heavy overrides: produces brittle
  CSS and still doesn't match the design.

---

## Decision 6: Color Token Strategy (No DaisyUI Theme Changes)

**Decision**: Define the Figma palette as a lightweight CSS layer in `app.css`
under a `.xui` prefix (or use Tailwind arbitrary values directly in templates).
These tokens are scoped to new components and do not touch DaisyUI variables.

**Token list** (used via Tailwind arbitrary values or class utilities):

| Purpose              | Value         | Usage                                  |
|----------------------|---------------|----------------------------------------|
| Page background      | `#f8f7f5`     | `bg-[#f8f7f5]` on root container       |
| Card surface         | `#ffffff`     | `bg-white` (already in Tailwind)       |
| Muted background     | `#ececea`     | `bg-[#ececea]`                         |
| Muted text           | `#717182`     | `text-[#717182]`                       |
| Border               | `rgba(0,0,0,0.08)` | `border border-black/[.08]`       |
| Overspent / error    | `#d4183d`     | inline `style` for dynamic coloring    |
| Positive balance     | `#10b981`     | inline `style` for dynamic coloring    |
| Primary (near-black) | `#030213`     | `text-[#030213]`, `bg-[#030213]`       |

Dynamic values (overspent vs. positive) use inline `style` attributes since
Tailwind cannot generate arbitrary values from runtime data.

**Rationale**: Arbitrary values are a first-class Tailwind feature and keep
the color definitions co-located with the HTML rather than hidden in a CSS
file. No new CSS layer is needed.

---

## Decision 7: Progress Bar Animation

**Decision**: CSS `transition-[width] duration-500` on the progress bar's
inner `div`, driven by the inline `style` attribute set during render.

**Rationale**: The Figma prototype uses Framer Motion (React), which is not
available in LiveView. CSS transitions on `width` achieve the same effect with
no additional dependency. LiveView's DOM diffing triggers the transition when
the percentage changes or on page load.

**Alternatives considered**:
- Alpine.js `x-transition`: adds a dependency for a trivial animation.
- No animation: acceptable fallback, but the CSS approach is standard and
  reliable.
