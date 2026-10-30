# Workstation configuration

Personal Nix configuration for operating systems, desktops, applications,
development tools, and coding agents across two machines:

- **Othinus:** NixOS with Niri, DankMaterialShell, and Vicinae.
- **Proserpina:** macOS with nix-darwin, OmniWM, and Raycast.

## Features

- Shared Catppuccin theme, Ghostty terminal, Zsh shell, and Neovim configuration.
- Development environments with Devenv, Git tooling, and command-line utilities.
- T3 Code, Codex, and Claude Code with shared instructions and skills.
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
Local package definitions are also available as flake package outputs.

## Updates and rebuilds

| Command | Action |
| ------- | ------ |
| `ns` | Build and switch the system, then activate staged coding agents and T3 Code. |
| `ns -u` / `ns --upgrade-packages` | Update inputs and stage releases, then build, switch, and activate. |

Both modes accept a checkout path, such as `ns -u /path/to/nixos-config`.
Without one, it uses the configured main checkout.
Nix update and rebuild commands reuse the GitHub CLI login when available.
T3 updates select one official nightly with matching server and desktop artifacts
for both machines. Update commands report failures and send system notifications.
Codex, Claude Code, and T3 Code stage and activate independently.

Devenv tracks upstream `main` and updates with `nup` and `nups`.

Coding agents and T3 Code receive scheduled Nix updates. Other applications update
manually through Nix. The frontend-design skill syncs from Anthropic with `ns -u`.
Built-in application updaters are disabled where supported;
apps manage their own plugins, extensions, tools, and content.

`ns -u` updates Nix-managed CA certificates along with applications and runtimes.
Applications with embedded trust stores receive fixes through their releases.
Restart running applications after updating. macOS updates and environments
managed separately by projects or uv remain separate update responsibilities.

Development checks are documented in [AGENTS.md](AGENTS.md).
