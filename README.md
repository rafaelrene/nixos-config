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

## Neovim

Neovim's package adds Go, GCC, and Python to its own PATH so Mason can install
Go tools and ansible-lint. These dependencies are not added to the global shell PATH.
Mason continues to manage editor tools.

The same wrapper supplies nightly Cargo, rustc, and the Rust standard library
for Mason packages built from Rust source, such as `nil`. The `rust-overlay`
flake input pins the latest available minimal nightly toolchain at lock-update
time. Update it with `nix flake update rust-overlay`, then rebuild to use a newer
nightly. Rust is not added to the global shell PATH.

NixOS enables `nix-ld` and its standard shared libraries system-wide so Mason's
downloaded Linux executables can run. LazyVim Extras continues selecting language
servers, formatters, and debuggers; nvim-treesitter installs grammars using
Mason's Tree-sitter CLI. Editor tools remain in Neovim's private data directory
and are not added to the global shell PATH. Apply this through the normal system
rebuild, then reopen Neovim to let missing parsers install. New Extras may need
additional libraries or installer runtimes; keep editor-only runtimes in Neovim's
package wrapper.

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

Ghostty uses 14.5pt text and an 80% opaque background. Niri blurs the wallpaper
behind Ghostty using two blur passes at offset 1, configured globally in Niri.
Its focus ring draws only around the window so it does not cover the wallpaper.
Selecting text copies it to the clipboard, trailing spaces are trimmed, and
terminal applications can read and write the clipboard. Super+Enter opens Ghostty.

After changing `themes/default.nix`, rebuild the system to regenerate
`/etc/xdg/ghostty/theme`, then reload Ghostty's configuration or restart it.
The selected theme supplies both the terminal colors and monospace font family.

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

## Shared agent configuration

Codex, Claude Code, and OpenCode share instructions, skills, and desktop
notifications from `config/agents/`. NixOS links these files directly into:

- Codex: `~/.local/share/codex` (`CODEX_HOME`)
- Claude: `~/.local/share/claude` (`CLAUDE_CONFIG_DIR`)
- OpenCode: `~/.config/opencode`

Editing a linked skill, hook, or setting changes the repository file immediately.
Restart the agent when it needs to reload configuration. Add or remove skill
directories under `config/agents/skills/`, then rebuild to reconcile their links.
Built-in skills, separately installed skills, credentials, sessions, databases,
and generated plugin dependencies remain outside the checkout.

The first activation backs up the imported Codex and Claude settings under
`~/.local/state/agent-config-backups/`. If either file has changed since import,
or another managed path contains an unrelated file/link, activation reports the
conflict and preserves it. Compare the conflicting file with its source under
`config/agents/`, retain the desired settings there, and move the original to a
backup before retrying. Do not delete a conflict blindly.

Run this on Othinus to include new files even before they are tracked by Git:

```sh
sudo nixos-rebuild switch --flake path:/data/code/nixos-config#othinus
```

NixOS declares the links and packages. The current checkout supplies mutable
contents, so restoring an older system generation does not restore previous
skill or settings contents; use Git for those. Othinus owns these files
independently of the Mac and has no Ansible dependency for agent configuration.

### Agent notifications

`~/.local/bin/agent-notify` sends “Agent needs attention” through the logged-in
user’s D-Bus notification service. It works from local terminals and SSH while
the Othinus desktop is running. Without a desktop service it exits quietly;
notification delivery never answers an agent’s permission request.

- Codex: completion, interruption, and permission requests.
- Claude: completion, API errors, and permission/idle/elicitation notifications.
- OpenCode: idle, errors, permissions, and questions; subagent events are ignored.

Test delivery with `~/.local/bin/agent-notify`. If no popup appears, check desktop
Do Not Disturb settings and `busctl --user --list` for
`org.freedesktop.Notifications`. Inspect link activation with
`journalctl --user -u nixos-activation.service -b` and verify targets with
`readlink -f ~/.local/bin/agent-notify`. Restart agents after hook configuration
changes. On first launch, Codex asks you to review the three new notification hooks;
trust them to enable delivery. Use `/hooks` to inspect them later. Mac forwarding
and Bitbucket CLI setup are deferred in `TODO.md`.

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
nix flake check --no-build path:/data/code/nixos-config
nix build --no-link path:/data/code/nixos-config#nixosConfigurations.othinus.config.system.build.toplevel
nix shell --inputs-from path:/data/code/nixos-config nixpkgs#python3 -c python3 -m unittest discover -s tests -v
node --test tests/test_opencode_notification.mjs
```

Use a previous NixOS generation from Limine if a system update fails. T3Code
and the agent tools use independent Nix profiles, so `nix-env --rollback` with
the relevant `--profile` can restore their preceding generation.

See [`TODO.md`](./TODO.md) for deferred work and [`adrs`](./adrs) for decisions
that should not be reopened without a changed constraint.
