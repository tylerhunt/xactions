# Research: Envelope Category Association

**Date**: 2026-04-10

---

## Decision 1: Database migration needed?

**Decision**: No migration required.  
**Rationale**: `envelope_categories` table and `EnvelopeCategory` schema already exist
(migration `20260409000010`). `BudgetEnvelope` already declares `has_many :envelope_categories`
and `has_many :categories, through: [...]`. `Budgeting` context already has
`assign_category/2` and `unassign_category/2`. Only application-layer wiring is needed.  
**Alternatives considered**: Adding a new join table — rejected; existing schema is identical.

---

## Decision 2: Category exclusivity constraint

**Decision**: One category belongs to at most one envelope; enforce at the DB layer.  
**Rationale**: `EnvelopeCategory` already carries a unique constraint on `category_id`:
`unique_constraint(:category_id, message: "category is already assigned to another envelope")`.
The UI must reflect this — categories already assigned to a different envelope should be
shown as disabled/unavailable in the picker.  
**Alternatives considered**: Allowing a category on multiple envelopes — rejected; existing
schema and spending calculation logic depend on exclusivity.

---

## Decision 3: Category sync strategy on update

**Decision**: Atomic delete-all + re-insert within a `Repo.transaction/1`.  
**Rationale**: Diff-based sync (delete only removed, insert only added) is more complex
and offers no practical benefit at the scale of this app (< 50 envelopes, < 100 categories).
A transaction-wrapped wipe-and-reinsert is simpler and safe.  
**Alternatives considered**: Diff-based sync — rejected for unnecessary complexity.

---

## Decision 4: Dropdown implementation in LiveView

**Decision**: Implement the dropdown using Phoenix LiveView JS `toggle/1` (show/hide)
on a positioned container. No Alpine.js or JavaScript hook needed.  
**Rationale**: The Figma design (`EnvelopeGrid.tsx`) uses `@radix-ui/react-dropdown-menu`
for the React prototype, but the project stack is Phoenix LiveView with no JavaScript
framework. LiveView JS `toggle/1` + Tailwind's `hidden` class achieves the same open/close
behaviour server-free. The trigger is a `hero-chevron-down` icon button inline after the
envelope name, matching the Figma design exactly.  
**Alternatives considered**: Alpine.js — rejected; not present in the project. A full
server-round-trip toggle — rejected; unnecessary latency for a UI-only concern.

---

## Decision 5: Category picker UI in create/edit forms

**Decision**: Render categories as a list of checkboxes.  
**Rationale**: Multi-select `<select>` elements are notoriously inconsistent across
operating systems and difficult to style. A checkbox list is simpler to render in
HEEx, visually consistent with the app's existing form style, and easy to test.  
**Alternatives considered**: Multi-select dropdown — rejected for styling complexity.
Token/tag input — rejected; over-engineered for this dataset size.

---

## Decision 6: Edit envelope form placement

**Decision**: Inline slide-in panel below the table row (not a modal).  
**Rationale**: The existing allocation edit is already done inline (the `editing_envelope_id`
assign controls an inline input). An inline edit panel below the row keeps the interaction
model consistent and avoids introducing modal infrastructure.  
**Alternatives considered**: Full-page modal — rejected; inconsistent with existing pattern.
Separate route — rejected; unnecessary navigation for a quick edit.
