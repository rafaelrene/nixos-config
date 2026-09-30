# Workstation configuration

Personal workstation configuration for all of
my machines (both NixOS and MacOS with nix-darwin).
This repository manages the operating system settings,
desktop, applications, development tools, and agent configuration, etc...

## Philosophy

- **Convenience comes first.** Keep workstation setup and changes in this
  repository and apply them through a system rebuild.

## Features

- **Linux desktop:** Niri, DankMaterialShell, application launchers, screenshot
  annotation, and power-aware display and idle settings.
- **Mac desktop:** Nix-managed applications and OmniWM window management.
- **Development environment:** Nushell, Ghostty, Neovim, Git, and Devenv,
  with shared settings where supported and a project script picker (`project-run`).
- **Coding agents:** T3Code, Codex, Claude Code, and OpenCode, with shared
  instructions, skills, themes, and rolling updates.
- **Consistent appearance:** A central Catppuccin palette for supported
  applications, plus a curated wallpaper collection.
- **Othinus services:** SSH and T3Code access over the LAN and Tailscale,
  encrypted SSH key provisioning, and local filesystem snapshots.
