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

**Decision**: Store the selected month as `{year, month}` integer assigns in
the LiveView socket. Navigation events (`prev_month`, `next_month`) increment
or decrement the date using `Date.shift/2` and reload budget data. No URL
params needed for MVP.

**Rationale**: All data fetches are already scoped to a `%Date{}` passed to
`Budgeting.list_envelopes/1` and `Budgeting.to_be_budgeted/1`. Switching
months only requires updating the date assign and re-running those queries.
LiveView handles the diff patch; no full reload occurs.

**Alternatives considered**:
- URL query params (`?month=2026-03`): better bookmarking, but adds routing
  complexity not needed for a personal-use app.
- Separate LiveView per month: unnecessary complexity.

---

## Decision 3: Monthly Income Source for Summary Cards

**Decision**: The "Monthly Income" card sources its value from
`Budgeting.to_be_budgeted/1` by also exposing `total_income/1` as a public
context function. Today `total_income` is private; it is promoted to public.

**Rationale**: The summary cards need four values: income, allocated, spent,
unallocated. Income and allocated already exist as private helpers; spent is
computed per-envelope. A small refactor exposes these without changing the
underlying query logic.

**Alternatives considered**:
- Compute income from envelope spending totals: incorrect — income is tracked
  separately via income-category transactions.
- Duplicate the query inline in the LiveView: violates context boundary.

---

## Decision 4: Inline Budget Editing Mechanism

**Decision**: Click-to-edit using a LiveView JS `push` event that sets
`editing_envelope_id` as a socket assign, toggling between a display span and
an `<input>`. On blur or Enter, `set_allocation` fires the existing event.

**Rationale**: The existing `set_allocation` event and `Budgeting.set_allocation/3`
function already handle persistence correctly. The only change is in the UI:
replace the always-visible form with a click-activated input. No new
server-side logic needed.

**Alternatives considered**:
- LiveView `JS.toggle` with hidden classes: fragile with form submission.
- Separate LiveComponent for editing: adds indirection for a simple toggle.

---

## Decision 5: Global Style Approach

**Decision**: Update the DaisyUI `light` theme in `app.css` to match the
Figma color tokens, and update `layouts.ex` navbar to add `sticky top-0`,
`backdrop-blur-sm`, and a semi-transparent background. Existing DaisyUI
component classes are retained on pages that already use them; the budget page
HTML is rewritten to the new table layout without DaisyUI card classes.

**Rationale**: The Figma design uses semantic color tokens (background,
card, border, muted-foreground) that map cleanly to DaisyUI's theme variables.
Updating the theme values propagates consistently across all pages without
touching each page individually. The navbar change is a two-line edit to
`layouts.ex`.

**Color token mapping**:
| Figma token          | Figma value           | DaisyUI variable       |
|----------------------|-----------------------|------------------------|
| background           | `#f8f7f5`             | `--color-base-100`     |
| card                 | `#ffffff`             | component-level class  |
| muted                | `#ececea`             | `--color-base-200`     |
| muted-foreground     | `#717182`             | `--color-base-content` (at 60%) |
| destructive          | `#d4183d`             | `--color-error`        |
| primary              | `#030213`             | `--color-primary`      |
| border               | `rgba(0,0,0,0.08)`    | `--color-base-300`     |

**Alternatives considered**:
- Introduce a separate CSS layer parallel to DaisyUI: unnecessary complexity,
  would require maintaining two theme systems.
- Port all pages to raw Tailwind without DaisyUI: large scope, out of bounds
  for this feature.

---

## Decision 6: Progress Bar Animation

**Decision**: CSS `transition-[width]` on the progress bar element,
driven by the inline `style` attribute set during render. No JS library.

**Rationale**: The Figma prototype uses Framer Motion (React), which is not
available in LiveView. A CSS transition on the `width` property achieves the
same visual effect without any additional dependency. LiveView's DOM diffing
will trigger the transition when the percentage changes.

**Alternatives considered**:
- Alpine.js `x-transition`: adds a dependency for a simple width animation.
- No animation: acceptable fallback if the CSS approach proves flaky, but
  the CSS approach is standard and reliable.
