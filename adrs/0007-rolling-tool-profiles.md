# ADR 0007: Use rolling Nix profiles for fast-moving tools

- Status: accepted
- Date: 2026-09-05

## Context

The operating system should remain on a pinned stable NixOS release. T3Code and
LLM agent CLIs change much faster and should stay current without rebuilding the
whole operating system.

## Decision

Package the official T3Code nightly artifact with Nix and stage it in its
independent profile every three hours. Restart the server daily at 04:00 to
activate the staged generation. For manual updates, `nix-update-packages`
refreshes the workstation flake inputs, runs the T3Code updater, and restarts
the server immediately. Applying workstation package updates remains a separate
NixOS rebuild and switch.

Update Codex CLI, Claude Code, and OpenCode from
`numtide/llm-agents.nix` in another independent profile each day. Never use
`npx` or an imperative language package manager for these tools.

Do not accept third-party flake configuration automatically. Keep only the
official NixOS cache and the Devenv cache globally trusted.

## Consequences

The tools can roll forward quickly and roll back independently. The first build
may take longer when a package is absent from the trusted caches.
