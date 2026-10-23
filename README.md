# Workstation configuration

Personal Nix configuration for operating systems, desktops, applications,
development tools, and coding agents across two machines:

- **Othinus:** NixOS with Niri, DankMaterialShell, and Vicinae.
- **Proserpina:** macOS with nix-darwin, OmniWM, and Raycast.

## Features

- Shared Catppuccin theme, Ghostty terminal, Zsh shell, and Neovim configuration.
- Development environments with Devenv, Git tooling, and command-line utilities.
- T3 Code, Codex, Claude Code, and OpenCode with shared instructions and skills.
- Native desktop applications, web app launchers, and local dictation on macOS.
- SSH key provisioning and Tailscale access; filesystem snapshots on Othinus.

## Architecture

The repository uses flake-parts and the dendritic pattern, without Home Manager.
Import-tree discovers the flake-parts modules.

- [Application modules](modules/applications/) expose individually selectable apps.
- [Profiles](profiles/) compose app modules and other bundles into shared and
  platform selections.
- [Hosts](hosts/) select bundles and declare hardware and machine-specific settings.
- [Themes](themes/) provide the shared palette.

Linux and macOS have separate Nixpkgs pins and explicit platform differences.
Git, Ghostty, Neovim, and agent settings support live editing from the checkout.

## Updates and rebuilds

| Command | Action                                           |
| ------- | ------------------------------------------------ |
| `ns`    | Rebuild and switch to the configured system.      |
| `nup`   | Refresh package sources and update rolling tools. |
| `nups`  | Update, then rebuild and switch.                  |

Each command accepts a checkout path, such as `ns /path/to/nixos-config`.
Without one, it uses the configured main checkout.

Coding agents and T3 Code receive scheduled Nix updates. Other applications update
manually through Nix. The frontend-design skill syncs from Anthropic with `nup`
and `nups`. Built-in application updaters are disabled where supported;
apps manage their own plugins, extensions, tools, and content.

`nups` updates Nix-managed CA certificates along with applications and runtimes.
Applications with embedded trust stores receive fixes through their releases.
Restart running applications after updating. macOS updates and environments
managed separately by projects or uv remain separate update responsibilities.

Development checks are documented in [AGENTS.md](AGENTS.md).
