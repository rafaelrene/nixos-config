# ADR 0009: Share application configuration with nix-darwin

- Status: accepted
- Date: 2026-09-20
- Amended: 2026-09-27

## Context

Othinus and Proserpina need common application settings, but have different
operating-system integrations and package requirements.

## Decision

Manage both hosts with NixOS and nix-darwin, composed through flake-parts using
the dendritic pattern throughout the repository. Every non-entry-point Nix file
is an outer flake-parts module, including infrastructure, hardware, themes,
development tooling, and package helpers. Shared helpers use typed feature
options; native modules remain values in that outer configuration. Feature files
are discovered automatically; a shared profile and explicit host imports select
applications.
Host identity, hardware, and machine choices remain in host configuration.
Maintain separate Linux and Darwin Nixpkgs pins.

## Consequences

Shared settings evolve together without forcing identical platform
implementations. Darwin package updates can leave the Linux Nixpkgs pin
unchanged; changes to shared inputs still require validation on both hosts.
