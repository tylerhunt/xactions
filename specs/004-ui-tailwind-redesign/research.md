# Research: UI Redesign — Remove DaisyUI

## Decision 1: Color Palette (Canonical)

**Decision**: Adopt the budget page palette as the app-wide design system.

| Token | Value | Usage |
|-------|-------|-------|
| Page background | `#f8f7f5` | Root container background on every page |
| Body text | `#030213` | All primary text |
| Muted / label text | `#717182` | Secondary labels, table headers |
| Hover / light fill | `#ececea` | Button hover backgrounds, active nav |
| Card border | `border-black/[.08]` | All white card outlines |
| Card surface | `white` | Cards, panels, tables |
| Danger / red | `#d4183d` | Error badges, negative balances, destructive actions |
| Success / green | `#10b981` | Positive balances, active sync status |
| Warning / amber | `#f59e0b` | MFA required, stale price warnings |

**Rationale**: The budget page was approved by the user. Codifying it here prevents drift.

**Alternatives considered**: Keeping DaisyUI theme tokens — rejected because DaisyUI tokens require a theme layer and produce the contrast failures being fixed.

---

## Decision 2: Button Styles

**Decision**: Two button variants, no DaisyUI `btn` class.

- **Primary** (dark fill): `px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors`
- **Ghost / secondary**: `px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors text-[#717182] hover:text-[#030213]`
- **Danger / destructive**: `text-xs text-[#717182] hover:text-[#d4183d] transition-colors`
- **Icon/small ghost**: `p-2 rounded-lg hover:bg-[#ececea] transition-colors`
- **Active/toggle** (e.g. period buttons): `px-3 py-1.5 rounded-lg text-sm transition-colors` + `bg-[#ececea] text-[#030213]` when active, `text-[#717182] hover:bg-[#ececea]/50` when inactive

**Rationale**: These are already proven on the budget page and navbar. Consistent with the navbar active-link pattern.

---

## Decision 3: Card/Panel Style

**Decision**: `bg-white border border-black/[.08] rounded-xl` for all cards, with `p-5` or `p-4` for padding.

Table containers use `overflow-hidden` to clip row borders at card corners.
Section headers within cards use `px-6 py-4 border-b border-black/[.08]`.

**Rationale**: Identical to the budget envelope table container.

---

## Decision 4: Input Style

**Decision**: `w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm` for text/select inputs. Error state adds `border-[#d4183d]`.

**Rationale**: From the budget create-envelope form. `core_components.ex` input component will be updated to use this as its base class.

---

## Decision 5: Alert / Banner Style (Replacing DaisyUI `alert`)

**Decision**: Inline banners use a colored left border + tinted background instead of DaisyUI alert classes.

- **Error**: `border-l-4 border-[#d4183d] bg-[#d4183d]/5 rounded-lg px-4 py-3 text-sm text-[#030213]`
- **Warning**: `border-l-4 border-[#f59e0b] bg-[#f59e0b]/5 rounded-lg px-4 py-3 text-sm text-[#030213]`
- **Info**: `border-l-4 border-[#3b82f6] bg-[#3b82f6]/5 rounded-lg px-4 py-3 text-sm text-[#030213]`

Flash toasts (from `core_components.ex`) retain their fixed-position toast layout but use the same colored left-border pattern.

**Rationale**: Removes DaisyUI dependency while preserving semantic color coding.

---

## Decision 6: Status Badge Style (Replacing DaisyUI `badge`)

**Decision**: Inline `<span>` with `text-xs font-medium px-2 py-0.5 rounded-full` and semantic background colors.

- `active` → `bg-[#10b981]/10 text-[#10b981]`
- `syncing` → `bg-[#3b82f6]/10 text-[#3b82f6] animate-pulse`
- `mfa_required` → `bg-[#f59e0b]/10 text-[#f59e0b]`
- `credential_error` / `error` → `bg-[#d4183d]/10 text-[#d4183d]`
- `inactive` → `bg-[#717182]/10 text-[#717182]`

**Rationale**: Same pill badge pattern used on the budget page for the "split" indicator.

---

## Decision 7: Stat/Summary Display (Replacing DaisyUI `stat`)

**Decision**: Use the budget page summary card pattern — no DaisyUI `stat` class.

For single-row stat groups (portfolio, reports), use `grid grid-cols-1 md:grid-cols-3 gap-4` with the same `bg-white border border-black/[.08] rounded-xl p-5` card.
Label: `text-sm text-[#717182] mb-1`. Value: `text-2xl tracking-tight` (or `text-3xl` for primary hero figure).

**Rationale**: Proven on the budget page; eliminates the `stat-title` / `stat-value` DaisyUI classes causing contrast failures.

---

## Decision 8: Modal Style (Replacing DaisyUI `modal`)

**Decision**: The MFA screen is already rendered inline by `mfa_live.ex` as a LiveView — it is not a true modal. Restyle as a centered card overlay using:
`fixed inset-0 bg-black/30 flex items-center justify-center z-50` for the backdrop, with the card inside using the standard `bg-white border border-black/[.08] rounded-xl p-6 w-full max-w-md`.

**Rationale**: The DaisyUI `modal modal-open` pattern is being removed. A simple fixed-position overlay with a backdrop is simpler and doesn't require DaisyUI.

---

## Decision 9: Account Balance Colors (Replacing DaisyUI `text-error` / `text-success`)

**Decision**: Replace `text-error` with `text-[#d4183d]` and `text-success` with `text-[#10b981]` in `account_card.ex`.

**Rationale**: Direct color values instead of DaisyUI semantic color tokens. Already the pattern used in `budget_live.ex`.

---

## Decision 10: Scope of `core_components.ex` Changes

**Decision**: Update only the `flash/1` and `button/1` component styling. The `input/1` component will also have its base classes updated. Other components (table, list, header, modal) in `core_components.ex` that are not actively used by any current live view will be left as-is rather than doing a full audit of the file.

**Rationale**: Minimizes risk and keeps the PR focused. The flash and button components are used on every page; the input is used in forms. Unused components are dead code risk but not a functional regression.
