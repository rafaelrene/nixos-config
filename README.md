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
All Nix configuration follows the dendritic pattern with flake-parts.
The [module guide](modules/README.md) covers repository-wide composition;
the [application guide](modules/applications/README.md) covers package ownership
and host selection.

## Features

- **Linux desktop:** Niri, DankMaterialShell, application launchers, screenshot
  annotation, and power-aware display and idle settings.
- **Mac desktop:** Nix-managed applications and OmniWM window management.
- **Development environment:** Nushell, Ghostty, Neovim, Git, and Devenv,
  with shared settings where supported and a
  [project script picker](modules/shell/scripts/README.md#project-scripts) (`prun`).
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
On Proserpina, `nup` selects OmniWM's latest stable upstream release; `ns` or
`nups` installs it and automatically restarts OmniWM when its package changes.

T3 Code checks its nightly channel every three hours and prepares the server
and desktop together. The server restarts daily at 04:00; `nup` restarts it only
when it installs a changed bundle. Reopen the desktop to use the new client.
Codex, Claude Code, and OpenCode update when user services start and daily at
04:30, with failed agent updates retried at roughly five-minute intervals.
See the [T3 Code guide](modules/applications/t3code/README.md) for package
definitions, failure behavior, and rollback.

Pass a checkout path to use a worktree: `ns .` rebuilds the current directory,
`nup .` updates it, and `nups .` updates it then rebuilds. Without a path, these
commands use the configured checkout.

See the [Proserpina guide](hosts/proserpina/README.md) for Mac setup and operation,
and the [SSH guide](modules/applications/openssh/README.md) for key provisioning and recovery.
Contributor constraints and validation commands live in [AGENTS.md](AGENTS.md).
Use direnv for repository development; see [DEVELOPMENT.md](DEVELOPMENT.md).

## Forgejo CLI

Both machines install [Forgejo CLI](https://codeberg.org/forgejo-contrib/forgejo-cli)
from Nixpkgs as `fj`. After rebuilding, run `fj version` to check the installed
version and `fj auth login --host https://codeberg.org` to sign in. Substitute
your own Forgejo instance URL as needed; credentials stay in the local user
configuration, outside this repository.

`nup` refreshes each machine's Nixpkgs pin; `ns` installs the pinned version.
`nups` does both. Releases follow the configured stable Nixpkgs channels, so
updates can lag behind upstream and the two machines can receive them at
different times.

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
