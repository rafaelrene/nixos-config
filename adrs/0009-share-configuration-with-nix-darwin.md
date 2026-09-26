# ADR 0009: Share application configuration with nix-darwin

- Status: accepted
- Date: 2026-09-20
- Amended: 2026-09-26

## Context

Othinus and Proserpina need common application settings, but have different
operating-system integrations and package requirements.

## Decision

Manage both hosts with NixOS and nix-darwin. Reuse portable application
configuration and package generators beside their features. Keep host settings
and platform-specific services separate. Maintain separate Linux and Darwin
Nixpkgs pins.

## Consequences

Shared settings evolve together without forcing identical platform
implementations. Darwin package updates can leave the Linux Nixpkgs pin
unchanged; changes to shared inputs still require validation on both hosts.
