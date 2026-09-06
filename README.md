# Othinus NixOS configuration

Declarative configuration for the Othinus development machine.

## Repository structure

- `hosts/othinus/`: machine hardware, disks, accounts, and explicit module imports.
- `modules/applications/`: Ghostty, Helium, Zen, Neovim, Vicinae, and desktop apps.
- `modules/desktop/`: Niri, DMS, shared desktop services, and GTK/Qt theming.
- `modules/services/`: SSH, T3Code, and local snapshots.
- `modules/development/`: agent tools, Git, and development runtimes.
- `modules/shell/`: Nushell and shell integration.
- `modules/system/`: boot, networking, Nix, and shared system settings.
- `themes/`: the selected palette, fonts, and application theme identifiers.

Each grouping’s `default.nix` explicitly imports its submodules. Each feature
owns its configuration, helpers, assets, package definitions, and documentation.
Use further subdirectories where useful; small shared settings can stay in the
grouping’s `default.nix`.

Removing a feature means removing its directory and import, then adjusting
explicit integrations: Niri shortcuts, Nushell tool settings, default application
associations, and root flake inputs or package exports. These are intentionally
manual. Existing application data is not deleted by removing a module.

## Themes

`themes/default.nix` selects `catppuccin.nix`, currently Mocha with a Mauve
accent. To add a theme, supply the same palette, font, and application-style
fields in another Nix file and select it there. GTK, Qt, the greeter, boot,
Niri, DMS, Ghostty, Neovim, and Vicinae consume this selection.

Application templates stay with their modules. Ghostty and Neovim keep editable
checkout configuration and read generated theme settings from `/etc/xdg`.
Vicinae keeps writable user settings; its native `VICINAE_OVERRIDES` mechanism
applies the selected theme and font without replacing other preferences.
DMS keeps its writable settings and receives the selected palette through its
linked `theme.json`; font settings are initial defaults and existing UI overrides
remain in effect.

## Normal updates

The operating system stays on the pinned NixOS 26.05 input until the lock file
is updated deliberately:

```sh
cd /data/code/nixos-config
nix flake update
sudo nixos-rebuild switch --flake .#othinus
```

`nh os switch` uses this repository by default through `NH_FLAKE` and is a
shorter equivalent.

Dark mode is the machine-wide default through dconf and the desktop settings
portal. GTK and Qt use Catppuccin Mocha; Qt applications such as Dolphin use
Kvantum with KDE integration and the matching color scheme. Helium launches
with `--force-dark-mode` for its browser UI. Theme defaults also live in
`/etc/xdg` for other users. After changing desktop theming, rebuild and log out
and back in so applications inherit the Qt plugin paths and theme environment.

T3Code checks the npm nightly tag every three hours, builds the official
artifact with Nix, and stages it in its own Nix profile. The server restarts at
04:00 to use the staged generation. Run `t3-update-now` to update and restart
immediately.

Codex CLI, Claude Code, and OpenCode update daily from
`numtide/llm-agents.nix`. Their wrappers automatically enter an allowed Devenv
environment when the project contains `devenv.nix` or `devenv.yaml`.

## SSH identities

`sudo nixos-rebuild switch --flake /data/code/nixos-config#othinus` provisions
the personal, Bitbucket work, and Othinus keys. On the first switch, choose an
archive passphrase at the terminal prompt; the decrypted Ansible keys are
encrypted into `modules/services/ssh/ssh-keys.age`. Commit that file after the
rebuild.
Restoring onto another machine requires only the committed bundle and its
passphrase. Later switches skip the prompt unless the bundle or installed keys
change. The personal key's existing SSH passphrase remains separate.

`~/.ssh/config` points to `modules/services/ssh/config` in this checkout. Editing
either path updates the Git working tree immediately; SSH config edits need no rebuild.
NixOS manages the SSH agent without Home Manager. See
[the SSH module documentation](./modules/services/ssh/README.md) for storage and
recovery details.

## T3Code access

T3Code listens on port 3773 and the firewall accepts it only from
`192.168.86.0/24`:

```text
http://othinus.local:3773
http://192.168.86.136:3773
```

The server stores its data in `/home/raf/.local/share/t3code`. Usage, token,
cost, and provider resource tracking remain enabled. Only PostHog analytics are
disabled.

Create a one-time pairing URL for the Mac desktop app or another LAN client:

```sh
ssh raf@192.168.86.136
t3 pair --base-dir /home/raf/.local/share/t3code
```

Systemd is the sole owner of the persistent T3 Code server. It starts during
boot, restarts after any unexpected exit, and retries without a rate limit.
Running bare `t3` shows its service status; `t3 start` and `t3 serve` are
blocked to prevent a second server from replacing its discovery state.

The Mac desktop owns its embedded Chromium preview even when the environment is
remote. Preview captures stay local to that desktop, while ordinary screenshot
attachments are uploaded to the Othinus environment with the message. The web
and mobile clients can send attachments but do not provide the desktop-only
embedded preview.

Link T3 Connect interactively:

```sh
ssh raf@192.168.86.136
t3 connect link --headless --base-dir /home/raf/.local/share/t3code
```

## Validation

```sh
nix flake check --no-build
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
```

Use a previous NixOS generation from Limine if a system update fails. T3Code
and the agent tools use independent Nix profiles, so `nix-env --rollback` with
the relevant `--profile` can restore their preceding generation.

See [`TODO.md`](./TODO.md) for deferred work and [`adrs`](./adrs) for decisions
that should not be reopened without a changed constraint.
