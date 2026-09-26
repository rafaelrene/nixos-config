# Workstation configuration

Personal workstation configuration for **Othinus** (NixOS) and **Proserpina**
(macOS with nix-darwin). This repository manages the operating system settings,
desktop, applications, development tools, and agent configuration for both machines.

## Philosophy

- **Convenience comes first.** Keep workstation setup and changes in this
  repository and apply them through a system rebuild.
- **Use native Nix options.** Prefer declarative packages, services, and
  configuration. Keep custom runtime logic small; do not use Home Manager.
- **Share what fits.** Reuse application settings and themes across machines,
  while keeping hardware and operating-system differences explicit.
- **Separate system and tool updates.** Pin the system configuration; let
  fast-moving tools such as T3Code and coding agents use independent Nix profiles.
- **Keep secrets outside the repository and Nix store.** Store credentials
  locally; only encrypted secret bundles belong in Git.

The [architecture decisions](adrs/) record the reasoning and accepted tradeoffs.

## Features

- **Linux desktop:** Niri, DankMaterialShell, application launchers, screenshot
  annotation, and power-aware display and idle settings.
- **Mac desktop:** Nix-managed applications and OmniWM window management.
- **Development environment:** Nushell, Ghostty, Neovim, Git, and Devenv,
  with shared settings where supported.
- **Coding agents:** T3Code, Codex, Claude Code, and OpenCode, with shared
  instructions, skills, themes, and rolling updates.
- **Consistent appearance:** A central Catppuccin palette for supported
  applications, plus a curated wallpaper collection.
- **Othinus services:** SSH and T3Code access over the LAN and Tailscale,
  encrypted SSH key provisioning, and local filesystem snapshots.

## Applying changes

Othinus uses the checkout at `/data/code/nixos-config`:

```sh
sudo nixos-rebuild switch --flake /data/code/nixos-config#othinus
```

Both configured shells provide `ns` to rebuild and switch, `nup` to update
package sources and rolling tools, and `nups` to update and switch. Rolling
tool updates can take effect independently of a system switch.

Pass a checkout path to use a worktree: `ns .` rebuilds the current directory,
`nup .` updates it, and `nups .` updates it then rebuilds. Without a path, these
commands use the configured checkout.

See the [Proserpina guide](hosts/proserpina/README.md) for Mac setup and operation,
and the [SSH guide](modules/services/ssh/README.md) for key provisioning and recovery.
Contributor constraints and validation commands live in [AGENTS.md](AGENTS.md).
Use `devenv shell` for repository development; see [DEVELOPMENT.md](DEVELOPMENT.md).

## Application launching

On Othinus, Vicinae defaults to **Launch app** when pressing Enter, including
when the app already has a window. Ghostty and Helium open another window;
other apps decide how to handle repeated launches. Per-app preferences in Vicinae can
override this default.

On Proserpina, Raycast uses its normal application-opening behavior, which can
focus an existing window. Its documented settings do not provide a global
always-open-a-new-window default.

For project folders and SSH connections, use the shared
[destination picker](modules/shell/scripts/README.md#destination-picker).
It explicitly opens a Ghostty window or focuses a matching terminal. The
shortcut is Ctrl+Alt+P on Othinus; assign Control+Option+P to **Open destination**
in Raycast on Proserpina.

## Future work

Deferred work lives in [TODO.md](TODO.md), including replacing DankMaterialShell
with a custom Quickshell desktop.
