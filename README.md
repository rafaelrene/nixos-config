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

All Nix configuration follows the dendritic pattern with flake-parts.

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

In Nushell, `fg` aliases `job unfreeze` to resume the latest job suspended with
Ctrl+Z; use `job list` to inspect jobs.

T3 Code checks its nightly channel every three hours and stages the server and
desktop together. At 04:00, or after `ns`, it activates the pair and reopens the
desktop if it was running. `nup` also requests activation; `nups` waits until its
system switch succeeds. `t3-activate` applies an already staged release without
checking the network. Activation can interrupt running agents.
Codex, Claude Code, and OpenCode check and stage releases at login and every
three hours, then activate at 04:00 for new sessions. `nup` and `nups` activate
them immediately. Codex and Claude follow their publishers' latest stable
channels; OpenCode follows Numtide. Failed checks retry after five minutes.

Pass a checkout path to use a worktree: `ns .` rebuilds the current directory,
`nup .` updates it, and `nups .` updates it then rebuilds. Without a path, these
commands use the configured checkout.

Contributor constraints and validation commands live in [AGENTS.md](AGENTS.md).
Use direnv for repository development: run `direnv allow` in a regular checkout,
or `devenv shell` to enter the development environment directly. Configured T3
worktrees are trusted automatically.

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

Option+Enter opens a fresh Ghostty window on Proserpina through Nix-managed skhd,
even when Ghostty is closed.

For project folders and SSH connections, run
`nav` or press Space Space
in normal mode at a Nushell prompt. It uses fzf to change directory or start
SSH in the current terminal.

Nushell uses Vi editing with a Space leader
for `nav`, `git nav`, and `project-run` on both machines.
