# ADR 0007: Use rolling Nix profiles for fast-moving tools

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-26

## Context

T3Code and coding agents need more frequent updates than the workstation system
configuration.

## Decision

Manage these tools through independent rolling Nix profiles on both hosts.
Keep T3Code's server and desktop on matching releases, promoted together after
successful builds.

## Consequences

Tools update and roll back independently of the system. Their versions are not
captured by the root flake lock, and restoring a system generation does not
restore their previous versions.
