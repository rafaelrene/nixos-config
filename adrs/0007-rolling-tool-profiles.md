# ADR 0007: Use rolling Nix profiles for fast-moving tools

- Status: accepted
- Date: 2026-09-05
- Amended: 2026-09-18

## Context

The operating system should remain on a pinned stable NixOS release. T3Code and
LLM agent CLIs change much faster and should stay current without rebuilding the
whole operating system.

## Decision

Package the official T3Code nightly server and desktop artifacts from the same
release with Nix. Stage them together in one independent profile every three
hours, only after both build successfully. Desktop launches follow this profile;
an open desktop must be reopened to use the new client.
Restart the server daily at 04:00 to
activate the staged generation. For manual updates, `nix-update-packages`
refreshes the workstation flake inputs, runs the T3Code updater, and restarts
the server immediately. `t3-update-now` updates only T3Code. Manual updates print
progress and build output in the terminal and share a lock with scheduled updates.
Applying workstation package updates remains a separate NixOS rebuild and switch.

Update Codex CLI, Claude Code, and OpenCode from
`numtide/llm-agents.nix` in another independent profile each day. On Othinus,
`nix-update-packages` also updates this profile; `update-llm-agents` updates only
the agents. Select all profile entries with `nix profile upgrade --all`.
Never use
`npx` or an imperative language package manager for these tools.

Do not accept third-party flake configuration automatically. Keep only the
official NixOS cache and the Devenv cache globally trusted.

## Consequences

The tools can roll forward quickly and roll back independently. The first build
may take longer when a package is absent from the trusted caches.
