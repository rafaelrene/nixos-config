# Workstation configuration

Declarative configuration for Othinus (NixOS) and Proserpina (nix-darwin).
See [Proserpina's migration notes](hosts/proserpina/README.md) for macOS setup,
Ansible compatibility, and native validation. The sections below describe Othinus
unless they explicitly mention macOS.

## Repository structure

- `hosts/othinus/`: machine hardware, disks, accounts, and explicit module imports.
- `hosts/proserpina/`: Apple Silicon Mac identity and checkout path.
- `modules/darwin/`: macOS packages, launchd services, and user-file activation.
- `modules/applications/`: Ghostty, Helium, Zen, Neovim, Vicinae, and desktop apps.
- `modules/desktop/`: Niri, DMS, shared desktop services, and GTK/Qt theming.
- `modules/services/`: SSH, Tailscale, T3Code, and local snapshots.
- `modules/development/`: agent tools, Git, and development runtimes.
- `modules/shell/`: Nushell and shell integration.
- `modules/system/`: boot, networking, Nix, and shared system settings.
- `themes/`: the selected palette, fonts, and application theme identifiers.

Each grouping’s `default.nix` explicitly imports its submodules. Each feature
owns its configuration, helpers, assets, package definitions, and documentation.
Use further subdirectories where useful; small shared settings can stay in the
grouping’s `default.nix`.

Portable generators stay beside their feature: Neovim's package, Ghostty's
palette, Starship and Nushell configuration, Git helpers, and agent themes and
updater. Both operating systems import those generators and the same editable
application files. NixOS retains its systemd wiring; macOS supplies its own
activation and launchd wiring. Darwin has a separate stable base and an unstable
package input, so updating macOS packages does not advance Othinus's Nixpkgs pin.
Proserpina uses Nixpkgs, upstream flakes and brew-nix for applications, runs a
separate T3Code server through launchd, and uses the desktop as its client.
Its `nup` updates Nix inputs, pinned vendor downloads, and rolling T3Code and
agent profiles; `nups` also switches the system. Homebrew is no longer a setup
dependency or package updater. Removal of replaced Brew packages is opt-in;
Proserpina now enables it for the final migration handover. The existing Zsh
Git/Try paths remain available.
Proserpina uses OmniWM with Caps Lock as its window-management modifier:
workspace 1 is Work, and workspaces 2–9 provide independent scrolling layouts.
See the [Mac window-management bindings](hosts/proserpina/README.md#window-management).
Quit existing Mac apps before opening their Nix copies during validation;
duplicate Proton Drive installations can mix app and File Provider paths.
See the [Mac guide](hosts/proserpina/README.md).

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
fields in another Nix file and select it there. The theme also declares whether
it is dark and supplies diff background colors. Keep its palette and packaged
GTK/Qt variants consistent. Changing `accent` in `themes/catppuccin.nix` selects
another color from the current palette.

| Applications | Managed appearance |
| --- | --- |
| GTK, including GTK 4/libadwaita | GTK theme, stylesheet, fonts, icons, cursor, and light/dark preference. |
| Dolphin, Ark, Gwenview, Okular, other Qt apps | Kvantum style and explicit KDE color roles, fonts, and icons. |
| T3Code | Published `othinus` palette; native desktop uses a custom-theme import, refreshed manually after palette changes. |
| Niri, DMS, greeter, boot | Borders, shell colors, login and boot themes. |
| Ghostty, Neovim, Vicinae | Generated terminal palette, editor theme, and launcher palette. |
| Codex, Claude Code, OpenCode | Generated `workstation` themes selected in their shared configuration. |
| Starship, Delta, fzf | Palette, diff colors, and picker colors. |
| Helium, Zen | Browser accent and light/dark appearance through native settings. |
| Satty, mpv | Annotation palette and GTK styling; playback background and on-screen text. |

Browser controls derive some colors themselves; web pages keep their own styles.
Application-specific themes and project-local agent settings can still override
system defaults. Newly installed applications with independent theme engines
need an explicit integration here.

Application templates stay with their modules. Ghostty and Neovim keep editable
checkout configuration and read generated theme settings from `/etc/xdg`.
Vicinae keeps writable user settings; its native `VICINAE_OVERRIDES` mechanism
applies the selected theme and font without replacing other preferences.
DMS keeps its writable settings. Before starting, its service merges the
declared appearance and power settings and disables Matugen's application-theme
generation so wallpaper changes cannot overwrite Nix-managed themes. Other
preferences remain intact. GNOME appearance keys are locked to the declared
theme so old per-user dconf values cannot mask a rebuild.

T3Code receives a regular JSON theme file before its server starts, since its
theme loader rejects file symlinks. The server selects `othinus` as its default;
a palette change reapplies that selection on clients with Othinus as their
primary environment. The native desktop currently ignores published themes
when its local environment is disabled and Othinus is a remote connection.
For that setup, import `~/.local/share/t3code/userdata/themes/othinus.json`
through Settings → Appearance → Add theme and select Catppuccin Mocha.
The generated file supports both server publication and custom-theme import.
After changing the central palette and rebuilding, reimport it and choose
to update the existing theme. Its stable `othinus` ID avoids duplicate themes.
This manual reimport is an accepted exception to automatic theme propagation.
A client following the published palette can choose a different theme until
the next declared palette change. The theme uses T3Code's
[native environment-theme support](https://github.com/pingdotgg/t3code/blob/main/apps/server/src/environmentTheme.ts).
Codex uses its [custom TextMate theme support](https://learn.chatgpt.com/docs/cli-customization);
Claude uses its [custom theme tokens](https://code.claude.com/docs/en/terminal-config#create-a-custom-theme).

The DMS top bar hides until the pointer reaches the top edge, leaving its space
available to windows. It appears over windows and stays visible while a bar menu
is open, then hides after the existing 250 ms delay. A DMS startup hook enables
auto-hide for the Main Bar without replacing other settings. Disabling auto-hide
in the UI lasts until DMS next starts.

Ghostty uses 14.5pt text and an 80% opaque background. Niri blurs the wallpaper
behind Ghostty using two blur passes at offset 1, configured globally in Niri.
Its focus ring draws only around the window so it does not cover the wallpaper.
Selecting text copies it to the clipboard, trailing spaces are trimmed, and
terminal applications can read and write the clipboard. Super+Enter opens Ghostty.

Super+Print triggers T3 Code's snapshot capture over the session D-Bus when
capture is enabled in T3 Code. Shift-only bindings intercept ordinary Shift
presses in Niri, so they are not used. The shortcut is declared
in Niri's configuration here because the generated `~/.config/niri/config.kdl` is read-only. After
applying this configuration, choose “I've added the shortcut” in T3 Code's
snapshot setup.

After changing the theme, rebuild and switch through the normal workflow, then
log out and back in so GUI apps inherit the new settings. Reload Ghostty or open
a new terminal, and restart editor and agent sessions. No separate theme setup
commands are required. Builds alone do not change the live desktop.

## Screenshots

Niri captures screenshots into the clipboard and automatically opens Satty for
annotation. Packages, editor settings, and the user service are managed by NixOS.

| Shortcut | Capture |
| --- | --- |
| Print | Select a region, then confirm in Niri. |
| Ctrl+Print | Full focused screen. |
| Alt+Print | Focused window. |

In Satty, add arrows, text, highlights, or other annotations. Press **Enter**
to copy the edited image to the clipboard and close, or **Escape** to discard
edits and close. The original capture stays in the clipboard until replaced.
Cancelling Niri's region selector does not open the editor.

Captures pass from the clipboard to Satty through a pipe; no screenshot files
are created. Satty has no default output filename and does not save after
copying. Explicitly choosing Save As in the editor can still save a file.
Existing files in `~/Pictures/Screenshots` are left untouched.

Apply through the normal NixOS rebuild. The `screenshot-annotation` user
service runs with the graphical session and listens for Niri capture events;
ordinary clipboard changes do not open Satty.

## Power management

DMS applies separate idle settings for external power and battery:

| Power source | Screen lock | Display off | Suspend |
| --- | --- | --- | --- |
| Plugged in, including fully charged | Never | Never | Never |
| Battery | After 10 idle minutes | After 15 idle minutes | After 15 idle minutes |

Locking keeps apps and agents running. Suspension pauses them and makes the
machine unreachable until resume. The AC policy keeps the desktop available
for agent control. DMS respects application idle inhibitors, which can delay
the battery timers. The power profile remains balanced on AC and power-saver
on battery.

Closing the lid suspends on battery unless docked, and is ignored on AC or
when docked. Lid-triggered and explicit suspend also lock first.
`Super+Alt+L` locks manually.

Rebuilds apply this policy to existing DMS settings. Changes made through the
DMS power settings last until its next service start.

## Display refresh rate

The internal display runs at 2560×1440, using fixed 60 Hz on battery and the
165 Hz mode with VRR enabled on AC power, including when fully charged.
The `niri-battery-refresh-rate` user service checks UPower at graphical
session startup and on power events, then applies temporary Niri mode and VRR settings.
It leaves external displays and disabled outputs alone. NixOS manages the helper
and its dependencies; it takes effect through the normal rebuild and switch.
Check unplug/replug and suspend/resume behavior after applying the change.

## Wallpapers

The repository's `wallpapers/` directory contains the wallpaper images and a
source catalogue. Nix selects one image per wallpaper and exposes the collection at
`~/Pictures/Wallpapers` during the normal system rebuild. In DMS's wallpaper
picker, browse that directory and select an image. DMS keeps the selection in
its writable settings, so rebuilds do not reset it.

The DMS package includes `modules/desktop/dms/wallpaper-rendering.patch` to keep
Qt's normal wallpaper update scheduling. DMS 1.4.6 otherwise disables updates
after a one-second timer, which can expire before the first frame if DMS starts
while the display is powered off. The result is a blank wallpaper on wake despite
the image loading successfully. When updating DMS, retain this fix until the
replacement passes a restart with the display off, wake, and wallpaper rotation.

Selection happens at rebuild time using `displayResolution` in
`modules/desktop/niri/default.nix`, which also sets Niri's display mode. Nix
prefers a matching `-2560x1440` variant with the same extension and otherwise
uses the original. Other resolution variants and the source catalogue stay out
of the exposed collection. DMS therefore sees each wallpaper once during rotation.

To add wallpapers, download the full-resolution originals into
`/data/code/nixos-config/wallpapers/`, use descriptive filenames with the source
ID, and record their sources in `wallpapers/README.md`. Keep every original.
If either dimension is below Othinus's 2560 × 1440 display, also add a version
enlarged proportionally to cover 2560 × 1440 and cropped to that size, with
`-2560x1440` before its extension. Include new files in Git so flake builds see
them, then rebuild. Image processing happens when adding an image, not at build
time. Image filenames use lowercase `.jpg`, `.jpeg`, `.png`, or `.webp`
extensions; reserve a trailing `-WIDTHxHEIGHT` for variants. Always make new
variants from the original, and keep the original in the repository.

## Shell prompt

The prompt shows directory and tool information on the first line and
`user@hostname` (normally `raf@othinus`) on the second line, locally and over SSH.

Nushell uses Starship with prompt settings in
`modules/shell/starship/starship.toml`. Nix combines these settings with the
shared theme palette into a Nix store file, linked at
`~/.config/starship/starship.toml` by systemd-tmpfiles, just like Nushell's
generated configuration. Nushell sets `STARSHIP_CONFIG` to this active file.
All Nushell integrations use `source` to load their build-generated hooks.
Rebuild after changing the settings
or theme, then open a new Nushell session. Bash does not enable Starship.
Othinus owns this configuration independently of Ansible.

## Shell aliases and Git

Nushell's `ls` runs `eza -la --icons=auto --group-directories-first`, showing
hidden entries and long details. `gs` runs `git status`; `gf` runs `git fetch`.
`gl` shows a compact colored Git history graph with short hashes, branch/tag
labels, subjects, relative ages, and authors. `gll` shows full hashes, labels,
dates (`YYYY-MM-DD HH:MM`), authors, and complete commit messages without a graph.
Both show the current branch's history by default and accept Git log arguments,
such as `gl --all` or `gll -20`. Colors are automatic; both use the existing Git
pager.
Both `v` and `vim` run `nvim`; `pn` runs `pnpm`.
Rebuild and open a new Nushell session after changing aliases.

Run `gf` to fetch, then `gp` to fast-forward to the cached upstream with
autostash. `gp` never fetches or rewrites commits; it stops if histories diverge
or no upstream is configured. Git restores tracked edits afterward, possibly
with conflicts; untracked files stay in place and staging may not be preserved.

Git configuration and global ignores live in
`modules/development/git/`, linked into `~/.config/git/`. They are independent
copies of the Ansible configuration. NixOS installs Delta for Git's pager and
interactive diffs. Delta settings are generated from the central Catppuccin
Mocha theme into a Nix store file linked at `~/.config/git/themes.gitconfig`.
Rebuild after changing the central theme.

Git retains the work identity, `master` as the initial branch, fetch pruning
and all-remotes fetching, automatic upstream setup and annotated-tag pushing,
rerere, rebase autostash, and submodule settings. The global ignore excludes
`.claude/settings.local.json` in every repository.

Git aliases: `undo` soft-resets the last commit; `rb` pulls from origin with
rebase and autostash; `rbd` does that for develop; `s` creates and checks out a
branch; `su`, `sui`, and `sup` update submodules, initialize them recursively,
and update them from remotes recursively. `git c` discards unstaged changes to
tracked files beneath the current directory.

## Bitbucket

Nix installs `bkt` alongside `gh` from the pinned upstream Linux release in
`modules/development/git/bitbucket.nix`. The release binary includes upstream's
public OAuth client configuration, allowing browser login and automatic token
refresh without creating a separate OAuth consumer.

After rebuilding, log out and back into the desktop with your password so
greetd can unlock GNOME Keyring. Then run this once in a desktop terminal:

```sh
bkt auth login https://bitbucket.org --kind cloud --web
bkt auth status
```

OAuth credentials stay in the local keyring, outside the repository and Nix
store. Host settings live in `~/.config/bkt/config.yml`. T3Code explicitly uses
Secret Service on the user's D-Bus, so its agents share the desktop credentials.
After a reboot, log into the desktop before using Bitbucket through T3Code.

In a Bitbucket checkout, verify `bkt pr list --json` from both the desktop and
T3Code. Repeat after the two-hour access-token lifetime to verify automatic
refresh. Bitbucket expires refresh tokens after three months without use;
revoked credentials or expired refresh tokens require another browser login.
See [Bitbucket's OAuth rules](https://developer.atlassian.com/cloud/bitbucket/rest/intro/#refresh-tokens).

For an SSH terminal after desktop login, select the same keyring explicitly:

```sh
env KEYRING_BACKEND=secret-service bkt auth status
```

## Scripts and command help

Nix packages the scripts in `modules/shell/scripts/` with their runtime
dependencies and links them into `/home/raf/.local/bin`, which is on PATH.
Nushell explicitly adds this directory at startup, including when its parent
process supplies a PATH without it. Open a new Nushell session after rebuilding.
`git branches [branch]` selects a branch with fzf or checks out the
given branch. `git delete-branches` (also `git db`) force-deletes local branches
other than the current branch, preserving branches checked out in worktrees and
printing cleanup commands for them. It must run from the main worktree.
The full `git-*` executable names also work directly.

Tealdeer provides `tldr` with the configuration in
`modules/applications/tealdeer/config.toml`, linked into `~/.config/tealdeer/`.
It uses a pager, colored examples, and automatic cache updates. Rebuild after
changing scripts or tealdeer configuration. These are independent copies from
Ansible; the Zentty scripts are deferred in `TODO.md`.

## Normal updates

Run `nix-update-packages` from any directory to refresh the flake inputs in
`/data/code/nixos-config`, then build and stage the latest T3Code nightly and
restart the server immediately. It prints T3Code update progress, downloads,
and build logs in the terminal. Run `t3-update-now` to update only T3Code.
Reopen the desktop app to use the staged client. Both commands stop if a
command fails; the updater retains a usable generation if a nightly cannot
be built and reports the fallback explicitly.

The operating system stays on its current packages until a separate rebuild
and switch applies the updated pins:

```sh
nix-update-packages
sudo nixos-rebuild switch --flake path:/data/code/nixos-config#othinus
```

Nushell provides three shortcuts:

| Command | Action |
| --- | --- |
| `ns` | Rebuild and switch Othinus using `/data/code/nixos-config`. |
| `nup` | Run `nix-update-packages`. |
| `nups` | Update packages, then rebuild and switch only if the update succeeds. |

Plain `nix flake update` still only refreshes flake inputs. T3Code's rolling
version remains in its independent updater state, outside the root `flake.lock`.

The selected theme's light/dark preference is exposed through dconf and the
desktop settings portal. GTK and Qt use Catppuccin Mocha; Qt applications such
as Dolphin use Kvantum with KDE integration and explicit palette settings.
Helium derives its browser theme from the declared accent and launches with
`--force-dark-mode` when the selected theme is dark. Theme defaults also live in
`/etc/xdg` for other users. After changing desktop theming, rebuild and log out
and back in so applications inherit the Qt plugin paths and theme environment.

T3Code checks the npm nightly tag every three hours, builds the official
server archive and desktop AppImage from the same release with Nix, and stages
them together in its own Nix profile only after both build successfully.
Scheduled and manual updates share a lock. The server restarts at
04:00 to use the staged generation. Manual `nix-update-packages` runs activate
T3Code immediately instead of waiting until 04:00.

Codex CLI, Claude Code, and OpenCode update daily from
`numtide/llm-agents.nix`. `nix-update-packages` also updates these agents;
`update-llm-agents` updates only the agents. Updates select every entry in their
independent Nix profile with `--all`. New launches use the updated versions;
running sessions keep their current processes.
Their wrappers automatically enter an allowed Devenv
environment when the project contains `devenv.nix` or `devenv.yaml`.

## Shared agent configuration

Codex, Claude Code, and OpenCode share instructions and skills from `config/agents/`. NixOS links these files directly into:

- Codex: `~/.local/share/codex` (`CODEX_HOME`)
- Claude: `~/.local/share/claude` (`CLAUDE_CONFIG_DIR`)
- OpenCode: `~/.config/opencode`

Editing a linked skill or setting changes the repository file immediately.
Restart the agent when it needs to reload configuration. Add or remove skill
directories under `config/agents/skills/`, then rebuild to reconcile their links.
The shared `login-dashboard` skill handles GroupSolver Dashboard authentication
in T3Code's browser. Its source lives here independently of the Ansible checkout.
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

T3Code handles agent notifications on each connected device. In Settings,
choose **Thread notifications → Notifications with sound** and allow browser
or system notification permission. T3Code must remain open. This setting is
stored on the client, not in the server's `settings.json`.

Use the desktop app or a secure browser origin. On Othinus, `http://localhost:3773`
is supported; `http://othinus.local:3773` is not a secure origin. For remote
browser access, use T3 Connect over HTTPS.

The NixOS rebuild removes the old notifier and agent hook links. On the Mac,
apply `/data/code/ansible` with `bash ./run.sh` to remove local hooks and unload
the SSH journal-forwarding LaunchAgent.

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

## Tailscale

NixOS runs Tailscale as a system service, starting at boot and retaining its
login in `/var/lib/tailscale`. It reconnects after sleep. Othinus stays awake
when idle on AC and suspends after 15 idle minutes on battery; it is unreachable
while suspended.

After the first rebuild and switch, enroll Othinus in your existing tailnet:

```sh
sudo tailscale up
```

Open the printed login URL and complete browser authentication. In the Tailscale
admin console, disable key expiry for Othinus so it does not periodically need
another login. These are one-time setup steps, not requirements for later
rebuilds or boots. No enrollment key belongs in this repository or the Nix store.

Tailscale accepts the tailnet's DNS settings, including MagicDNS when enabled.
Othinus joins as a regular device, with no exit node, subnet routing, or
Tailscale SSH. OpenSSH keeps its existing key authentication.

The firewall permits TCP ports 22 and 3773 on `tailscale0` and UDP port 41641
for the encrypted tunnel. Existing LAN rules remain unchanged. Tailnet access
policies must also permit connections to these services.

Check the connection locally:

```sh
systemctl status tailscaled
tailscale status
tailscale ip -4
```

From another tailnet device, use `ssh raf@othinus` and
`http://othinus:3773` when MagicDNS is enabled, or substitute Othinus's full
MagicDNS name or Tailscale IP. Verify both services from outside the LAN, confirm
the existing LAN addresses still work, and check reconnection after reboot and
sleep/resume.

## T3Code access

T3Code listens on port 3773 and the firewall accepts it from
`192.168.86.0/24` and the Tailscale interface. Existing LAN addresses:

```text
http://othinus.local:3773
http://192.168.86.136:3773
```

The server stores its data in `/home/raf/.local/share/t3code`. Usage, token,
cost, and provider resource tracking remain enabled. Only PostHog analytics are
disabled.

T3Code's provider settings explicitly point to the Codex and Claude data
directories under `/home/raf/.local/share`. Its usage scanner does not use
`CODEX_HOME` or `CLAUDE_CONFIG_DIR`; without these settings it scans empty default
directories and reports zero usage. Before each server start, systemd merges
the declared provider paths into the saved settings, preserving other preferences.

The **T3 Code** desktop launcher uses the official nightly AppImage packaged
with Nix. Its embedded server is disabled; pair it with the systemd server.
Native desktop settings under `~/.local/share/t3code/userdata/` start with
`localEnvironmentEnabled: false` and `notificationMode: "notifications-and-sound"`.
These are writable defaults, so later desktop preferences are preserved.
Desktop updates come from the rolling T3Code profile, with Electron auto-updates
disabled. The launcher uses the staged client each time it opens; updating the
profile does not close an already running desktop app. After the initial NixOS
switch installs this updater, neither server nor desktop updates need a system
rebuild. The updater uses `~/.local/state/t3code-bundle-updater`; the old
server-only updater directory is no longer used. The updater creates its own
directory before use, including during a NixOS switch, and keeps its package
files writable without overwriting versions staged by earlier updates.

Create a one-time pairing URL for the Othinus or Mac desktop client:

```sh
ssh raf@192.168.86.136
t3 pair --base-dir /home/raf/.local/share/t3code
```

Systemd is the sole owner of the persistent T3 Code server. It starts during
boot, restarts after any unexpected exit, and retries without a rate limit.
Running bare `t3` shows its service status; `t3 start` and `t3 serve` are
blocked to prevent a second server from replacing its discovery state.

T3Code's integrated terminals use Nushell, including its aliases and startup
hooks. The service PATH includes `/home/raf/.local/bin` so Git helpers such as
`git db` are available to terminals and child processes. T3's POSIX login-shell
PATH probe can log a warning with Nushell; the service supplies PATH explicitly.
After rebuilding, run `systemctl --user restart t3code.service` and open a new
terminal to load the changed environment.

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
```

Use a previous NixOS generation from Limine if a system update fails. T3Code
and the agent tools use independent Nix profiles, so `nix-env --rollback` with
the relevant `--profile` can restore their preceding generation.

See [`TODO.md`](./TODO.md) for deferred work and [`adrs`](./adrs) for decisions
that should not be reopened without a changed constraint.

## Web apps

Search `Webapp` in Vicinae for browser app launchers. T3Code uses the native
desktop client instead.

`Oryx (ZSA Voyager Keyboard Config) Webapp` opens
`https://configure.zsa.io/voyager` in Helium and uses the browser icon.
NixOS enables ZSA's udev rules for Voyager flashing and live training in Oryx.
After applying the configuration, reconnect the Voyager if Oryx cannot access
it, then select the keyboard in Oryx's connection prompt. Keymapp and a
`plugdev` group are not required.

To add another, invoke the project-local
[add-webapp skill](.agents/skills/add-webapp/SKILL.md) with its URL and app name:

- Codex: `$add-webapp https://example.com "Example"`
- Claude Code: `/add-webapp https://example.com "Example"`
- OpenCode: `Use the add-webapp skill with URL https://example.com and app name Example.`

The skill prepares and checks the Nix changes. Apply them through the
existing NixOS rebuild workflow when ready.
