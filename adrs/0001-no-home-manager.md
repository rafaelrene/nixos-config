# ADR 0001: Do not use Home Manager

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-26

## Context

Both workstations manage system and user configuration from this repository.
They already share application settings and use platform-specific activation.

## Decision

Continue using native NixOS and nix-darwin modules without Home Manager.
Reuse portable configuration across hosts.

## Consequences

We maintain user-file linking and conflict handling ourselves. Reconsider this
decision if maintaining that code becomes more work than adopting Home Manager.
