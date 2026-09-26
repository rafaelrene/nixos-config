# ADR 0010: Keep documentation focused

- Status: accepted
- Date: 2026-09-26

## Context

Repeating configuration details and task history across documents makes them
harder to maintain and obscures useful guidance.

## Decision

Keep README.md an overview and AGENTS.md a short working guide. Put necessary
operational details beside their feature and deferred work in TODO.md. Use ADRs
only for useful ongoing constraints or non-obvious rationale, not merely to
record completed setup. Link instead of duplicating; report validation results
in change summaries.

## Consequences

Update documentation when the information it conveys changes. Most
configuration edits do not require README changes or a new ADR.
