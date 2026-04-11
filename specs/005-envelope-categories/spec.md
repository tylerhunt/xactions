# Feature Specification: Envelope Category Association

**Feature Branch**: `005-envelope-categories`
**Created**: 2026-04-10
**Status**: Draft
**Input**: User description: "Envelopes should be associated with one or more categories. Allow associating categories when creating envelopes. Allow editing envelopes by clicking a dropdown menu trigger next to the envelope name in the Envelopes table."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Envelope with Categories (Priority: P1)

When creating a new envelope, the user selects one or more categories to associate with it before saving.

**Why this priority**: Category association is a core part of envelope creation — an envelope without categories is incomplete and cannot be properly classified for reporting or budgeting purposes.

**Independent Test**: A user can open the new envelope form, assign categories, save the envelope, and see it appear in the Envelopes table with its categories visible.

**Acceptance Scenarios**:

1. **Given** the new envelope form is open, **When** the user selects one or more categories from the available list and saves, **Then** the envelope is created and its associated categories are stored and displayed.
2. **Given** the new envelope form is open, **When** the user attempts to save without selecting any category, **Then** the form prevents submission and shows a validation message indicating at least one category is required.
3. **Given** categories exist in the system, **When** the user opens the new envelope form, **Then** the full list of available categories is presented for selection.

---

### User Story 2 - Edit Envelope via Dropdown Menu (Priority: P2)

A user can edit an existing envelope — including its name and category associations — by opening a dropdown menu triggered from the envelope's row in the Envelopes table.

**Why this priority**: Envelopes need to remain maintainable after creation. The dropdown menu keeps the table uncluttered while providing inline access to edit actions.

**Independent Test**: A user can click the dropdown trigger next to an envelope name, choose "Edit", modify the name or categories, and confirm the changes are reflected in the table.

**Acceptance Scenarios**:

1. **Given** the Envelopes table is visible, **When** the user clicks the dropdown trigger next to an envelope name, **Then** a menu appears with at least an "Edit" option.
2. **Given** the dropdown is open, **When** the user selects "Edit", **Then** an edit form opens pre-populated with the envelope's current name and categories.
3. **Given** the edit form is open, **When** the user changes the name or adds/removes categories and saves, **Then** the Envelopes table reflects the updated values.
4. **Given** the edit form is open, **When** the user removes all categories and attempts to save, **Then** the form prevents submission and shows a validation message indicating at least one category is required.

---

### Edge Cases

- What happens when no categories have been created in the system yet — can an envelope still be created?
- What happens if a category is deleted that is currently associated with one or more envelopes?
- How does the dropdown behave if the user clicks outside of it without selecting an action?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each envelope MUST be associated with one or more categories; an envelope with zero categories is invalid.
- **FR-002**: The envelope creation form MUST include a multi-select category picker showing all available categories.
- **FR-003**: The system MUST prevent saving an envelope (on create or edit) if no categories are selected, displaying a clear validation message.
- **FR-004**: Each row in the Envelopes table MUST display a dropdown menu trigger adjacent to the envelope name.
- **FR-005**: The dropdown menu MUST include an option to edit the envelope.
- **FR-006**: The edit form MUST be pre-populated with the envelope's existing name and category associations.
- **FR-007**: Users MUST be able to add or remove category associations when editing an envelope.
- **FR-008**: Changes made via the edit form MUST be immediately reflected in the Envelopes table upon saving.

### Key Entities

- **Envelope**: A named budget container that holds one or more category associations. Key attributes: name, associated categories (one or more).
- **Category**: A classification label that can be linked to envelopes. Key attributes: name, identifier.
- **Envelope–Category Association**: The relationship linking an envelope to a category. An envelope may have many; each must reference a valid category.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create an envelope with category associations in under 60 seconds.
- **SC-002**: 100% of envelopes in the system have at least one category — the system enforces this at the point of save and rejects invalid submissions.
- **SC-003**: Users can open the edit form for any envelope within 2 clicks from the Envelopes table.
- **SC-004**: Changes to an envelope's name or categories are visible in the Envelopes table immediately after saving, without requiring a page reload.

## Assumptions

- Categories are pre-existing data in the system; creating or managing categories is out of scope for this feature.
- The Envelopes table is an existing view; this feature adds a dropdown menu trigger column and wires up the edit flow.
- Only authenticated users with access to the budget management area can create or edit envelopes.
- The dropdown menu in the Envelopes table will follow the existing visual design conventions of the application (consistent with other table action menus if present).
- Mobile support uses the same interaction patterns as desktop; no separate mobile-specific flow is needed for v1.
