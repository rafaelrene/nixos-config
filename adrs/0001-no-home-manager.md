# ADR 0001: Do not use Home Manager

- Status: accepted
- Date: 2026-09-05

## Context

Most user configuration is small and belongs with this single-machine NixOS
configuration. A second module system and another activation lifecycle would
add more concepts than they remove.

## Decision

Manage packages, services, environment variables, and user accounts with
NixOS. Keep editable configuration files in this repository and install them
with systemd-tmpfiles links or Nix-rendered files.

## Consequences

There is one system rebuild workflow. Per-user configuration that needs complex
merging may require a small NixOS module or an explicit activation step later.
Reconsider Home Manager only when that concrete need exists.
