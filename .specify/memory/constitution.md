<!--
SYNC IMPACT REPORT
==================
Version change: 1.0.0 → 1.1.0

Modified principles:
  - Development Workflow: added mandatory static analysis gate after tests pass

Added sections: None
Removed sections: None

Templates reviewed:
  - .specify/templates/plan-template.md        ✅ Constitution Check section aligns
  - .specify/templates/spec-template.md        ✅ No changes required
  - .specify/templates/tasks-template.md       ✅ No changes required

Follow-up TODOs: None
-->

# xactions Constitution

## Core Principles

### I. Code Quality

Every line of code MUST be written for the next person who reads it. Features MUST be
implemented as the simplest possible solution that satisfies the requirements — no
speculative abstractions, no pre-emptive generalization. Complexity MUST be justified
explicitly in the plan's Complexity Tracking table.

- Functions MUST have a single, clearly-named responsibility.
- Dead code MUST be removed; commented-out code is not permitted in commits.
- Dependencies MUST be introduced deliberately — each new dependency requires a stated
  rationale in the PR description.
- Code review MUST verify that no new complexity was introduced without a documented
  reason.

### II. Test-First Development (NON-NEGOTIABLE)

TDD is mandatory. Tests MUST be written and reviewed by the user before any
implementation begins. The red-green-refactor cycle is strictly enforced:

1. Write a failing test that describes the desired behavior.
2. Get user approval that the test captures intent correctly.
3. Confirm the test fails (red).
4. Implement only enough code to make the test pass (green).
5. Refactor with tests green throughout.

No implementation task may be marked complete unless its tests existed first and passed
after implementation. Skipping or retroactively adding tests is a constitution violation.

### III. Integration & Contract Testing

Unit tests alone are insufficient. Each feature MUST include integration tests that
exercise the full path through the system against real dependencies (not mocks). Contract
tests MUST be written for all inter-service or inter-module interfaces.

- Contract tests MUST live in `tests/contract/` and cover every public interface.
- Integration tests MUST run against real storage/services, not test doubles.
- New contracts MUST have contract tests before any consumer code is merged.
- Breaking a contract MUST trigger a MAJOR version bump and a migration plan.

### IV. User Experience Consistency

Every user-facing surface — CLI output, API responses, error messages, and documentation
— MUST follow a single, consistent vocabulary and interaction model. Inconsistency in
UX is treated as a bug.

- Error messages MUST include: what went wrong, why it happened, and how to fix it.
- CLI commands MUST follow the established verb-noun pattern for all subcommands.
- API responses MUST use consistent field naming (snake_case) and status codes across
  all endpoints.
- New interaction patterns require explicit design approval before implementation.

### V. Performance Requirements

Performance requirements are first-class feature requirements and MUST be specified in
the spec before implementation begins. Unspecified performance is not acceptable.

- Every feature MUST document its performance goal in `plan.md` under Technical Context.
- Latency targets MUST be stated as p95 values (e.g., `<200ms p95`).
- Features that touch critical paths MUST include a benchmark in the test suite.
- Performance regressions MUST be flagged in code review and MUST NOT be merged without
  explicit sign-off.

## Development Workflow

Pull requests MUST be small, self-contained, and independently reviewable. A PR that
cannot be reviewed in under 30 minutes is too large. Branch names follow the repository
convention (`###-brief-description`).

- Each PR MUST link to a spec and pass the Constitution Check in `plan.md`.
- All tests MUST pass before review is requested.
- Static analysis MUST pass after all tests are green and before review is requested.
  Warnings that cannot be addressed immediately MUST be documented in the PR description
  with a follow-up ticket.
- PRs MUST NOT include unrelated changes or speculative improvements.
- Commits MUST follow the 50/72 rule (subject line ≤50 chars, body lines ≤72 chars).

## Governance

This constitution supersedes all other development guidance. Amendments require:

1. A written proposal describing the change and rationale.
2. Identification of all templates and artifacts that must be updated.
3. A version bump per semantic versioning:
   - **MAJOR**: Removal or redefinition of an existing principle.
   - **MINOR**: Addition of a new principle or material expansion.
   - **PATCH**: Clarification, wording, or non-semantic refinement.
4. Update of `LAST_AMENDED_DATE` on the day the amendment is merged.

All PRs and code reviews MUST verify compliance with this constitution. When in doubt,
simpler is better and tests come first.

**Version**: 1.1.0 | **Ratified**: 2026-04-09 | **Last Amended**: 2026-04-10
