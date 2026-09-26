# ADR 0010: Keep documentation focused

- Status: accepted
- Date: 2026-09-26

## Context

Requiring a root README update for every behavior change turned the project
overview into a catalogue of settings, procedures, and validation notes. This
made the project's purpose and philosophy harder to find and duplicated details
already recorded in configuration and feature documentation.

## Decision

Keep the root README high level: project purpose, philosophy, main features,
basic rebuild workflow, and links to further documentation and deferred work.
Update it when that overview changes.

Keep AGENTS.md a small operational guide: a one-line project overview, working
principles, agent-specific boundaries, and essential validation commands. Link to
the README and relevant ADRs instead of repeating their explanations or policies.

Put necessary setup, operational, and troubleshooting instructions beside the
relevant host or feature. Explain implementation details in configuration or
nearby comments when needed. Do not document every setting or copy validation
transcripts into the README; report task validation in the change summary.

Keep actionable deferred work in TODO.md. Use ADRs for durable decisions,
constraints, and accepted tradeoffs rather than feature inventories or task logs.

## Consequences

Documentation stays current at the level it describes. Most configuration
changes do not need a root README edit. Add detail where someone needs it to
operate or maintain a feature, and link to it instead of duplicating it.
Existing platform and architecture decisions remain unchanged.
