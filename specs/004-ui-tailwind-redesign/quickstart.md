# Quickstart: UI Redesign — Remove DaisyUI

## Setup

```bash
git checkout 004-ui-tailwind-redesign
mix test   # confirm baseline green before any changes
```

## Restyle Order (TDD)

For each page/component, follow the red-green pattern:

1. Add `data-*` attributes to the existing template (if missing)
2. Write a failing test asserting no DaisyUI classes + new selector
3. Confirm test is red with `mix test path/to/test`
4. Replace DaisyUI classes with raw Tailwind equivalents
5. Confirm tests are green

## Page Order

Work through pages in this order (P1 first):

1. **Shared components** (unblocks everything):
   - `sync_status_badge.ex` — pill badge pattern
   - `account_card.ex` — raw Tailwind hover + balance colors
   - `core_components.ex` — flash, button, input

2. **Dashboard** — most visible, uses account_card + sync_status_badge
3. **Accounts** — uses account_card + sync_status_badge
4. **Transactions** — largest file; work section by section
5. **Portfolio** — stat → summary cards; period toggle
6. **Reports** — stat → summary card; date form
7. **Login** — card → centered white card
8. **MFA** — modal → fixed overlay

## Design Reference (Budget Page Patterns)

See `research.md` for the full design token reference.

**Quick cheat sheet**:
```
Page root:    min-h-screen bg-[#f8f7f5]
Card:         bg-white border border-black/[.08] rounded-xl p-5
Label:        text-sm text-[#717182] mb-1
Value:        text-2xl tracking-tight (text-3xl for hero)
Primary btn:  px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors
Ghost btn:    px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors text-[#717182] hover:text-[#030213]
Input:        w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm
Error alert:  border-l-4 border-[#d4183d] bg-[#d4183d]/5 rounded-lg px-4 py-3 text-sm
Warning:      border-l-4 border-[#f59e0b] bg-[#f59e0b]/5 rounded-lg px-4 py-3 text-sm
Badge pill:   text-xs font-medium px-2 py-0.5 rounded-full bg-[COLOR]/10 text-[COLOR]
```

## Validation

After all changes:

```bash
mix test           # must be 0 failures
mix format         # fix any formatting
```

Then do a visual review at `http://localhost:4000` against each page.
