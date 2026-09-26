# Proserpina

Apple Silicon, user `rafael`, home `/Users/rafael`, checkout
`/Users/rafael/code/.personal/nixos-config`. The flake output is
`darwinConfigurations.Proserpina`.

The Ansible repository remains unchanged. No activation calls Ansible or loads
configuration from it. Othinus retains its existing configuration and services.

## Scope

| Feature | macOS configuration |
| --- | --- |
| Shell and runtimes | Nushell login shell, Starship, zoxide, Devenv and Node 24. Existing Mise installations remain untouched. |
| Editor | Shared LazyVim configuration, theme, and private Mason installer runtimes. |
| Git | Shared configuration, Delta theme, ignores, and branch helpers. |
| Terminal | Ghostty from Nix, shared palette, Mac Option key and quick-terminal settings. |
| Desktop apps | Nixpkgs, upstream flakes and brew-nix; no Homebrew installation required. |
| Window management | OmniWM scrolling columns, Caps Lock shortcuts, and nine workspaces; workspace 1 is Work. |
| Agents | Shared rules, skills and themes; Codex, Claude Code and OpenCode use an independent rolling Nix profile. Pi comes from Nixpkgs. |
| Mac helpers | Existing Raycast web launchers and Zentty helpers imported unchanged. |
| SSH | Client configuration only. Existing keys and the macOS SSH agent remain in place. |

The Mac does not import Niri, systemd services, the Linux SSH server, snapshots,
or Othinus's network exposure rules. A separate launchd service runs T3Code on
`127.0.0.1:3773`; its desktop is a client. Tailscale keeps the native Mac app.

## Package sources

The system uses flake inputs rather than imperative `nix-channel` subscriptions:

| Source | Purpose |
| --- | --- |
| `nixpkgs` / `nixos-26.05` | Othinus, unchanged by Mac package updates. |
| `nixpkgs-darwin` / `nixpkgs-26.05-darwin` and nix-darwin 26.05 | Stable Mac base, shell and development environment. |
| `nixpkgs-unstable` | Newer Discord, IINA, Mailspring, OmniWM, OrbStack, Proton Pass, Raycast, Shottr, Yaak, Devenv, Graphite and Pi. |
| `brew-nix` and `brew-api` | Native Mac releases for Anytype, Ente Photos/Auth, Gifox, Microsoft Teams, ONLYOFFICE, Proton Drive, RustDesk, Signal, Slack, Standard Notes, Superwhisper, Tailscale, Telegram, Thaw, Chromium, WhatsApp and Zentty. |
| Upstream flakes | Zen, Helium and Try; independent profiles handle T3Code and agent tools. |
| `vendor-sources.json` | Complete Google Drive and Viber app payloads with explicit versions and hashes. |

FreeTube and Ghostty retain their tested stable Nixpkgs
packages. brew-nix reads cask metadata and produces Nix derivations; it never
runs Brew. Thaw uses the signed **3.0.0-alpha.7** release for macOS 27, with its
update channel set to `alpha`. Its archive and checksum are pinned in
`modules/darwin/packages.nix`; update that override for later alpha releases.
The stable cask does not support macOS 27. Telegram remains the native Mac
client. Filen uses the signed vendor bundle through brew-nix; the Nixpkgs
launcher uses Electron's generic data directory instead of the vendor's
application identity.

Raycast has a 2.5.2 minimum: the migrated Mac's databases already use that
release's schema, which 2.4.1 cannot open. Until the unstable input catches up,
the package uses the signed upstream 2.5.2 archive and checksum. Newer Nixpkgs
versions take precedence automatically. Compare the running app version before
replacing self-updated applications; a Brew receipt can report an older version.

Slack, Teams and Signal use cask metadata because their Nixpkgs versions lagged
behind the vendors: Teams blocked the old client, Slack offered an in-app
update, and Signal 8.25 could not open the existing schema-1800 database.
Teams retains Nixpkgs' extraction of only the app payload, excluding the
bundled Microsoft AutoUpdate application. Their cask versions advance through
`nup`/`nups`. Activation writes Slack's `AutoUpdate = false` policy to
`/Library/Managed Preferences/com.tinyspeck.slackmacgap.plist`. Slack requires
an enforced policy and ignores this key in ordinary user preferences. Quit and
reopen Slack after activation so it reads the policy. Its app bundle remains
signed and unmodified.

Google Drive's package extracts only the Apple Silicon app, excluding Google's
updater and document shortcuts. Viber uses its complete app payload, not the
small online installer distributed by its cask. Both vendors overwrite their
download URLs, so `nup` downloads and inspects them before atomically updating
the version/hash manifest. Historical builds need their original downloads in
the Nix store or a cache if the vendor no longer serves those bytes.

Viber's package omits the updater manifest outside its signed resources and
verifies the bundle signature during the native build. Discord's native updater
ignores the older skip-update settings. Activation installs a pinned manifest
generated from Nixpkgs' host/module versions and hashes and enables it without
replacing other Discord settings. Discord downloads its initial runtime modules
using that manifest; subsequent version changes follow `nup` and a rebuild.
Its signed app bundle remains intact, including when opened from Finder.

Zen associates default profiles with the installation path. Moving from
`/Applications/Zen.app` to `/Applications/Nix Apps/Zen Browser (Beta).app` can
select a fresh profile even though the original data remains intact. On
Proserpina, the new installation's default was reassigned to the original
`exaq0x7r.Default (release)` profile in `profiles.ini` and `installs.ini` while
Zen was closed. The original profile and registries were backed up under
`~/.local/state/nix-darwin/backups/zen-2026-09-25`. Future rebuilds retain the
same installed app path and profile association.

[nixpkgs-multiverse](https://github.com/fzakaria/nixpkgs-multiverse) was considered.
It indexes existing Nixpkgs revisions for version selection and recovery; it
does not supply missing Mac packages. A stable base, one unstable input and
brew-nix cover the current requirements without another resolver.

## Window management

OmniWM replaces Amethyst. Nix installs its signed app, links a generated
`~/.config/omniwm/settings.toml`, and starts it through a user launchd agent.
Edit `modules/darwin/omniwm/settings.nix` and rebuild; the GUI cannot save over
the Nix-store configuration. OmniWM's own update checks are disabled.

All nine workspaces use independent horizontal scrolling columns. Workspace 1
is labelled **Work**; 2–9 are available for other activities. Switch to Work
before opening work windows. Apps are not assigned globally because a browser
or terminal can have both work and personal windows. Move existing columns
between workspaces with the shortcuts below.

New columns use the full available width. Width cycling follows Othinus:
⅓, ½, ⅔, full. Focused columns center on overflow; gaps are 2 points and the
focus border uses the shared theme. OmniWM's menu bar item names the current
workspace. Hold Caps Lock to show the workspace bar with each workspace's apps;
it overlays the top of windows so they keep the full height. Holding Control
for 200 ms shows it too.

Hold **Caps Lock** wherever Othinus uses Super. Nix remaps it to Right Control
in the keyboard driver, so it never toggles capitals, even on a tap. The
built-in keyboard has no Right Control, so OmniWM's Right Control shortcuts
only fire from Caps Lock; the left Control key still reaches apps. Caps Lock
with a key OmniWM does not use reaches the app as Control plus that key.
Caps + Control chords are impossible, so moves use Shift instead of Othinus's
Control. Workspace numbers use Option, which previously switched native
desktops.

| Shortcut | Action |
| --- | --- |
| Caps + left/right | Focus columns |
| Caps + up/down | Focus windows in the column, then the adjacent workspace |
| Caps + Shift + left/right | Move the whole column |
| Caps + Shift + up/down | Move the window within its column, then to the adjacent workspace |
| Option + 1–9 | Switch workspace; 1 is Work |
| Option + Shift + 1–9 | Move the focused column to a workspace |
| Caps + Page Up/Down | Previous/next workspace |
| Caps + Shift + Page Up/Down | Move the column to the previous/next workspace |
| Caps + O | Overview across workspaces |
| Caps + R / Caps + Shift + R | Cycle column width forward/backward |
| Caps + minus/equal | Decrease/increase column width by 10% |
| Caps + F | Toggle full-width column |
| Caps + Shift + F | Toggle managed fullscreen without entering a native Space |
| Caps + V | Toggle floating |
| Caps + Q | Close the focused window |
| Caps + [ / ] | Consume a window into the column / expel it |

On the built-in keyboard, Fn+up/down supplies Page Up/Down. Three-finger
horizontal swipes scroll columns; three-finger vertical swipes change
workspaces. Four-finger up/down opens/closes overview. Nix disables the
conflicting macOS trackpad gestures. Option + Command + mouse drag moves tiled
windows; Option + Command + right-drag resizes them. Mouse modifiers cannot be
side-specific, and Control-click is right-click.

Nix owns macOS's keyboard shortcut list (`com.apple.symbolichotkeys`). It
disables Mission Control's Control+arrow shortcuts, desktop switching, and
earlier choices such as Spotlight's Command+Space for Raycast. Shortcuts not
listed in `modules/darwin/omniwm/default.nix` revert to macOS defaults. macOS
applies changes at the next login.

OmniWM workspaces replace native Spaces for this workflow. Keep one native
macOS desktop and use the nine OmniWM workspaces. OmniWM only manages windows
on the current native desktop, so a window on another desktop is unreachable.
Do not assign apps to desktops through the Dock's Options menu. These are
configured workspaces, not Niri's automatically added/removed empty workspaces.
OmniWM accepts one binding per action, so this configuration uses Othinus's
arrows rather than also duplicating H/J/K/L. Workspace reordering and Niri's
modifier+wheel workspace switching are not mapped. Launch Ghostty through
Raycast or its existing Mac shortcuts; Caps+Enter does not launch applications.

For the first authorized switch, quit Amethyst and disable its login item if
one remains. Nix removes the old managed app. The declared “Displays have
separate Spaces” setting requires a logout/login on this Mac. Launchd then
starts `/Applications/Nix Apps/OmniWM.app`. Grant it Accessibility and Input
Monitoring in the macOS permission dialog, plus Screen Recording for overview
thumbnails. Return to OmniWM's permission window to continue. These macOS
permissions cannot be pre-granted by Nix. Leave OmniWM's separate “Start at
Login” option off because launchd already owns startup.

The complete schema snapshot in `modules/darwin/omniwm/defaults.json` comes
from [OmniWM v0.7.1's canonical settings model](https://github.com/OmniNull/OmniWM/blob/v0.7.1/Sources/OmniWM/Core/Config/CanonicalTOMLConfig.swift).
Upstream requires every hotkey
action, even unassigned ones. A version assertion stops upgrades until that
snapshot and the generated configuration have been checked against the new
release; otherwise a rejected file can silently start with upstream defaults.

## Prerequisites and activation

Validate through Nix evaluation, builds, and focused native checks before an
authorized live switch. A macOS VM is no longer required; see ADR 0009.

The target needs an existing `rafael` account, the checkout at the declared
path, Xcode Command Line Tools, and a multi-user Nix installation.
These are bootstrap prerequisites, not post-rebuild scripts. See the
[nix-darwin installation guide](https://github.com/nix-darwin/nix-darwin#readme).
This configuration lets nix-darwin manage Nix; an independently managed
Determinate Nix installation needs its own explicit configuration decision.

Build without activation:

```sh
nix --extra-experimental-features 'nix-command flakes' build --no-link 'path:/Users/rafael/code/.personal/nixos-config#darwinConfigurations.Proserpina.system'
```

The following commands change the target system and require Rene's explicit
instruction. First activation:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake 'path:/Users/rafael/code/.personal/nixos-config#Proserpina'
```

The official Nix installer may modify `/etc/bashrc` and `/etc/zshrc` in a way
that nix-darwin does not recognize. If activation reports these files, inspect
them against their `.backup-before-nix` copies. After preserving any custom
settings, rename the reported files with the `.before-nix-darwin` suffix and
retry. Do not bypass this check or overwrite unrelated system configuration.

Subsequent activation:

```sh
sudo darwin-rebuild switch --flake 'path:/Users/rafael/code/.personal/nixos-config#Proserpina'
```

Nushell provides `ns` for switching, `nup` for updating all package sources,
and `nups` for updating then switching. `nup` refreshes stable Darwin and unstable
Nixpkgs, nix-darwin, shared Rust/browser inputs, brew-nix/cask metadata and Try.
It refreshes the Google Drive/Viber manifest, updates and restarts T3Code, and
updates all three rolling agent packages. Nix system packages take effect after `ns` or
`nups`. Updating shared Rust and browser pins affects Othinus's next rebuild too.
Failures stop the command and are reported; a failed update does not switch the
system. Close and reopen desktop applications to use updated versions.

The module disables Homebrew removal by default. Proserpina's host configuration
now enables it for the authorized final handover. For a new migration, first
disable `workstation.removeReplacedHomebrewPackages`, then build and validate the Nix
configuration while keeping the existing Brew installations. Once the migration
is verified, set `workstation.removeReplacedHomebrewPackages = true;` in
`hosts/proserpina/configuration.nix` and rebuild. That activation uninstalls only
the named Brew apps, fonts and CLI tools replaced by Nix, including the old T3Code cask.
Run this handover from Apple's Terminal: Brew's Zentty uninstall quits Zentty,
which would interrupt a rebuild running there. Writing Proton Drive's sandboxed
updater preferences requires Full Disk Access; sudo alone does not grant it.
On macOS 27, the privacy log attributes nix-darwin's `launchctl asuser` write to
the Nix-store `bash` running activation. Enable that **bash** entry under System
Settings > Privacy & Security > Full Disk Access. Terminal's permission alone
is insufficient for this process chain. If `bash` is absent, add the exact Nix
Bash binary named by the activation script's shebang. A Bash package update can
change that path and require granting access again. Keep this access available
for subsequent rebuilds that write the same preferences.
Save work and wait for cloud sync
to finish, then quit the replaced desktop apps before activation. Reopen their
Nix copies afterward; Google Drive, RustDesk and Tailscale may need macOS prompts
answered locally. Verify Finder access, synchronization, VPN and remote access.
Agent cleanup waits until the rolling Nix profile contains each replacement.
Formulae required by other installed Brew packages remain. Cleanup never uses
`--zap`, `--force`, autoremove or global Brew cleanup: application data and
unrelated Brew packages remain. Homebrew may request Automation permission to
remove an application's login items. Launch the Nix copies from
`/Applications/Nix Apps`. Homebrew is consulted only for this migration cleanup,
which is skipped on clean machines without Brew. Unrelated legacy Brew packages
are neither removed nor updated by this configuration.

During staging, quit each existing app before opening its Nix copy. Proton Drive
can launch the Nix File Provider while its old app is still running, producing
“FileProvider has launched from outside the current Drive app.” Quit Proton Drive
and open `/Applications/Nix Apps/Proton Drive.app`, then check an existing file in
Finder. Both the app and its extension must run from that bundle. Retaining both
copies can cause this mismatch again; restarting is a staging workaround, not
a completed app handover. Do not delete File Provider data or sign out to fix
an installation-path mismatch.

nix-darwin installs real app bundles. With Homebrew removal enabled, Google Drive and RustDesk also have
compatibility links at their vendor's expected top-level `/Applications` paths;
activation refuses unrelated files at those paths. Google Drive's installed
mount helper receives its vendor-required root ownership and setuid permission.
Tailscale/Proton Drive/Thaw automatic Sparkle updates and Google Drive's vendor
updates are disabled so Nix controls their installed versions. `nup`/`nups`
refreshes the normal package sources; Thaw's alpha override requires a
version/hash edit. Before final handover, existing vendor paths and updater
preferences are left in place, including Discord's
settings. Google Drive and RustDesk need the final handover to validate their
Nix copies at the vendor paths; keeping both copies is only a staging step.
Unmanaged vendor-path conflicts are checked before activation changes files or
removes packages, and checked again immediately before creating the links.

T3Code's server and desktop are built from the same official nightly release and
staged together in `~/.local/state/nix/profiles/t3code`. A matching bootstrap pair
is included in the system closure, so startup does not wait for an online update.
Quit the existing T3Code desktop and its embedded server before the first
activation. A listener on port 3773 blocks activation unless the nix-darwin
T3Code service is already registered. Preserve the existing
`local.t3code.bitbucket-env` launch agent; it supplies the Mac's Bitbucket
environment without putting credentials in this repository.
Launchd starts the server
at login, restarts it on failure, checks for updates every three hours, and
restarts it daily at 04:00. `nup` activates the new server immediately. Open
**T3 Code** in `/Applications/Nix Apps` for the client. Its launcher disables
the embedded server and application self-updater while preserving other native
preferences. Pair it with the local server using `t3 pair`; the connection is
saved by the client. The server uses the shared palette and Devenv-aware agent
wrappers. Logs live in `~/.local/state/nix-darwin/t3code*.log`.

The server package marks node-pty's macOS `spawn-helper` executable during the
build. Without that permission, every embedded terminal shell fails with
`posix_spawnp failed`; T3Code's attempted runtime repair cannot modify the Nix
store. The existing rolling updater's cached package definition was repaired
too, preserving its current server and desktop versions.
The repaired profile was activated and the managed server restarted. Native
verification exercised Nushell startup, command input and output through the
packaged PTY; the server responds on port 3773. The complete Darwin build,
formatting and lint passed, and Othinus's unchanged derivation built on Othinus.

Devenv is the project runtime manager. Declare language versions and project
tools in each project's `devenv.nix`; the shared Nushell hook and agent wrappers
enter that environment. Node 24 and Clang remain workstation bootstrap tools,
as on Othinus. Existing Mise data is preserved but no longer configured.
Conda and direnv are not configured by the Mac module; direnv is not included
in its explicit tool list. Existing Zsh initialization remains untouched.
The login shell and Ghostty use `/nix/var/nix/profiles/system/sw/bin/nu`, which
remains available before boot activation recreates `/run/current-system`.

The agent updater runs at login and daily at 04:30 through launchd. Failed
updates retry after at least five minutes, including when Nix is still starting.
Manual updates are included in `nup`; its scheduled log is
`~/.local/state/nix-darwin/agents-update.log`. The first update must finish before
the Nix profile's agent commands are available. The replaced Homebrew Pi package is removed; unrelated packages remain. The shared Nix launchers take precedence in Nushell's PATH and
enter the project's Devenv environment before starting an agent.
The Mac trusts Numtide's signed binary cache for these packages and uses Nix's
explicit `--all` selector when upgrading the profile.

## Existing files and state

Activation checks all declared user-file destinations before changing any of
them. It replaces matching Ansible symlinks and its own previously recorded
links. A real file or unrelated symlink at a destination aborts activation with
its path. Reconcile that file before retrying; the hook never overwrites it.

Ansible directory symlinks such as `~/.config/git` are retained as
`~/.config/git.before-nix-darwin`. Real directories take their place, containing
individual managed links. The files behind the old link stay untouched in the
Ansible checkout. The installation manifest lives at
`~/.local/state/nix-darwin/links.json`; stale links are removed only while they
still point to their last recorded target.

Existing `~/.codex`, `~/.claude`, `~/.pi/agent`, and `~/.t3` directories remain
where they are. Their XDG counterparts alias them, preserving credentials and sessions.
Clean installations create XDG directories directly. If both locations already
exist, activation stops rather than choosing one. Agent settings stored as real
files are subject to the same conflict checks as other configuration.
Codex's editable host settings live in `hosts/proserpina/codex.toml`; its theme
is shared, while project trust paths belong to this Mac. Claude's Mac preferences
live in `hosts/proserpina/claude.json`, preserving its model, permission mode,
editor and notification settings. Before the first switch, compare the live
settings with these files, back up both, and retire the conflicting regular
files only as part of the handover. Never copy credentials into the checkout.

On a fresh installation, `~/.t3` links back to the XDG T3Code directory. macOS
restores the signed upstream desktop directly at login, potentially before
launchd supplies `T3CODE_HOME`. This compatibility link keeps its saved connection
and disabled embedded server intact during restoration.

Existing SSH private keys are neither imported nor decrypted by the Mac module.
The SSH client config links to a read-only Nix-store copy, since OpenSSH rejects
a group-writable checkout file even through a symlink. Editing
`modules/darwin/ssh.config` takes effect after `ns`.
A fresh VM can test client configuration without work credentials. Existing Zsh
files, local secrets and shell history are left untouched. Switching shells does
not translate Zsh-only secret exports into Nushell; project secrets should stay
in their existing external secret storage or project environment.

`~/.local/share/raycast/scripts` contains the unchanged Raycast launchers. Select
that directory in Raycast’s Script Commands settings instead of `~/.web-apps`.
An existing Ansible link is left untouched; a link installed by an earlier
nix-darwin generation is retired automatically. The launchers still use Chromium. The imported Zentty helpers still explicitly open
Zsh panes; the default login shell and Ghostty use Nushell. The legacy
`~/.config/git/.gitconfig` path remains available, and Try's upstream-generated
Zsh integration is installed at `~/.config/try-rs/try-rs.zsh` for these panes.
Both the current Mac and this repository use LazyVim; their plugin pins and
some plugin settings differ.

macOS still controls application sign-in and privacy permissions. For example,
Ghostty's global quick-terminal shortcut needs Accessibility permission. These
prompts are not bypassed by activation.

## Validation

From Linux, evaluate both systems and build Othinus:

```sh
nix flake check --no-build path:.
nix eval --raw 'path:.#darwinConfigurations.Proserpina.system.drvPath'
nix build --no-link 'path:.#nixosConfigurations.othinus.config.system.build.toplevel'
```

Building the Darwin closure requires macOS. Build the system and run focused
native checks for the change, such as app signature verification, configuration
decoding, and launchd plist validation. Activation and interactive checks follow
an explicitly authorized live switch; report any checks still pending. Evaluation
and builds do not authorize changing running services. A VM is not required.

### OmniWM configuration validation (2026-09-26)

- Passed Nix formatting, Statix, Deadnix, all-system flake evaluation, and the
  complete Darwin system build. The built app set contains OmniWM and omits Amethyst.
- Decoded the rendered TOML as JSON through the upstream v0.7.1 Swift settings
  model in a temporary native checker: 9 workspaces, all 188 required actions,
  and 41 assigned shortcuts without conflicts. Gesture validation also passed.
- Checked numbered workspace navigation and column transfers, Caps Lock's
  modifier composition, Work's label, and the Niri width presets. Verified the
  app signature and generated launchd plist. Temporary checks were removed.
- Othinus's system derivation remained unchanged and built successfully on Othinus.

The authorized live switch succeeded after granting the Nix-store Bash Full Disk
Access for Proton Drive's preference write. Launchd started OmniWM, its IPC ping
responded, and workspace queries showed Work plus eight other Niri workspaces.
The previous writable settings file was preserved under
`~/.local/state/nix-darwin/backups/omniwm-2026-09-26.bWXKhA/`.

OmniWM reported Accessibility granted, but its input services had not started:
“Displays have separate Spaces” still requires logout/login to take effect.
Caps Lock interception, gestures, overview rendering, and management of actual
work windows remain unverified until then. An IPC response alone does not prove
that these services are running. The temporary diagnostic capture was removed.

After logging back in, Rene confirmed that windows, workspaces, and the bar
worked. Helium was unreachable because its window was on a leftover native
desktop. Rene deleted the extra desktops; the Dock's app-to-desktop assignments
were cleared with `defaults delete com.apple.spaces app-bindings`.

The Caps Lock remap switch succeeded. `hidutil` reported Caps Lock mapped to
Right Control, no symbolic hotkey remained enabled, and `activateSettings -u`
reloaded them. A trace capture showed 23 side-specific shortcuts, no
registration failures, and OmniWM's own Caps Lock remap inactive. The capture
was removed. Rene then confirmed the shortcuts and the bar reveal from the
keyboard.

### Testing environment retired (2026-09-25)

Rene requested deletion of the testing VM, downloaded images and Tart after
validation. The `proserpina-test` VM and its dedicated directory,
`/Users/rafael/Library/Caches/proserpina-vm-testing`, were removed. The older
`dotforge-tahoe-base` VM and cache in `~/.tart` were also removed with explicit
approval. ADR 0009 now uses native validation; do not recreate this environment
for routine Darwin changes.

The test VM used `ghcr.io/cirruslabs/macos-tahoe-base:latest`, macOS 26.6.2,
two CPU cores, 4 GiB RAM and a 120 GB virtual disk. Its account was renamed to
`rafael`; it had no host-home mount or forwarded work credentials.

### Migration safeguards validated (2026-09-25)

- Built the complete Darwin system with Homebrew cleanup disabled and enabled.
- Activated the default configuration twice; checked Nushell startup, the
  legacy Git path, Try's Zsh function with completion initialized, and T3Code HTTP.
- Rejected an unmanaged Google Drive bundle and an occupied T3Code port before
  user-link activation. Restored all temporary test fixtures afterward.
- Activated cleanup mode on the VM without Brew; verified the vendor links
  and Google Drive's root-owned, setuid mount helper. Earlier tests below cover
  Homebrew removal itself.
- Passed Linux evaluation, lint and the Othinus build. Othinus's system
  derivation remained unchanged.

The work Mac's live configuration was not activated during these tests. VM testing does not cover
its macOS 27 permissions, account sign-in, cloud synchronization or VPN sessions.

A subsequent clean build on the work Mac exposed a Tailscale wrapper that
required the installed app during packaging. The wrapper now resolves that path
at launch. Its package build and generated shell wrapper were checked on the
Mac; Rene approved native checks for this fix without recreating the deleted VM.
Viber's overwritten download URL also required refreshing its pin to 28.10.0.
The new archive's metadata and signature were checked on the work Mac; its
developer identity matches the installed Viber application.

### First live activation (2026-09-25)

Rene completed the first switch locally with Homebrew removal disabled. SSH
checks confirmed the active system, Nushell login shell, Git and Neovim binaries,
managed agent-setting links, and installed Codex, Claude Code and OpenCode
profiles. Both scheduled updaters exited successfully. The managed T3Code server
listened on localhost port 3773 and returned HTTP 200.

The retained Proton Drive app received an extension launch from the Nix copy.
Quitting the old app and opening the Nix copy aligned both running executable
paths. Rene confirmed the warning disappeared and an existing file opened in Finder;
upload/download synchronization has not been independently tested.

### Final live handover (2026-09-25)

Rene completed activation with Brew cleanup enabled. The declared Brew app and
CLI replacements were removed; unrelated MongoDB Compass and other formulae
remain. A partial JetBrains Mono uninstall required restoring 17 stored font
files to their missing user-font destinations before normal cleanup could finish.
The old Graphite formula needed temporary, formula-specific Homebrew trust after
source review; that trust was revoked after removal.

SSH checks confirmed the Google Drive and RustDesk compatibility links, Google's
root-owned setuid mount helper, disabled vendor updater settings and Discord's
pinned update manifest setting. Google Drive and RustDesk signatures passed.
All four apps started from `/Applications/Nix Apps`; Tailscale reported online
with no health warnings. Google Drive and Proton Drive each had one registered
File Provider extension from the Nix copy. Managed T3Code still returned HTTP 200.
Rene confirmed Google Drive and Proton Drive file access and synchronization,
Tailscale connectivity, and RustDesk readiness after answering local prompts.

Raycast's “failed to restart” error came from downgrading its self-updated 2.5.2
bundle to Nixpkgs' 2.4.1. The corrected Nix package opens all 11 existing
databases, and Rene confirmed it works. The package was launched directly from
the Nix store; applying the built system to replace the installed copy remains
pending. See the [Raycast handover](RAYCAST-HANDOVER.md) for validation and state.

Thaw 2.0.1 displayed its macOS 27 incompatibility alert. The replacement
3.0.0-alpha.7 Nix package passes signature verification and launches on the
host with the alpha channel selected. Existing preferences and app-support
state were backed up under `~/.local/state/nix-darwin/backups/thaw-2026-09-25`.
It is running from the Nix store until the next authorized system switch.

Both fixes pass formatting, lint, full flake evaluation and the Darwin build.
Othinus's derivation is unchanged and its build passed on Othinus. Activation
testing in a new VM and the live system switch have not been performed.

### Nix-only package validation (2026-09-20)

Validated in the retained VM with the Homebrew executable unavailable:

- Built and activated the complete system repeatedly, installing 35 app bundles
  through Nix. Booted Nushell and the launchd T3Code server after a reboot.
- Ran `nup` through Nix input updates, Google Drive/Viber version and hash
  inspection, matching T3Code server/client updates, and all three agent updates.
  The system generation stayed unchanged until `ns` applied the updated sources.
  Restored the repository's pins afterward; Othinus's derivation stayed identical.
- Launched the desktop apps with Gatekeeper enabled. Fixed Viber's unsigned
  updater manifest, Discord's native updater, Proton Pass's signature, Filen's
  application identity, and the Tailscale/Zentty CLI entry points during testing.
- Approved Tailscale's network extension through macOS's normal dialog and ran
  its CLI. Google Drive and Proton Drive registered their File Provider extensions
  and reached onboarding. Viber reached phone pairing; its optional Opera offer
  was declined.
- Rejected an unmanaged Google Drive application conflict without deleting it.
  Verified Drive's installed mount-helper permissions and preservation of
  unrelated Google update policies during repeated activation.
- Paired the T3Code desktop with the launchd server with its local environment
  disabled. Closing the desktop left the same server process serving HTTP.
- Ran Devenv 2.3.1 with a project-declared Node 24 runtime and entered that
  environment through the Codex wrapper. Codex, Claude Code, OpenCode and Try
  reported their installed versions.

These checks cover packaging, activation, launch and update behavior. They do
not cover account sign-in, cloud synchronization, VPN connectivity, OrbStack's
nested virtualization, or every application's complete workflow. No work
credentials were added, and the work Mac's configuration was never activated.

### Initial migration VM results (2026-09-20, before removing Homebrew)

Validated with Tart on Apple Silicon, using macOS 26.6.2:

- Built the complete Darwin system and activated it repeatedly.
- Installed 17 Nix application bundles and the remaining 19 Brewfile dependencies
  (18 apps and Try). Launched the Nix applications with Gatekeeper enabled.
- Paired the native T3Code client with the launchd server, verified the embedded
  server was disabled, and confirmed the server survived closing the desktop.
  Reopening the updated client restored its saved connection.
- Ran `nup` and `nups`: updated Nix inputs, built matching T3Code server/client
  releases, updated all three agent tools, upgraded Brew packages, and applied
  the new system. Restored this checkout's lock file for the final pinned build.
- Removed a replaced Brew Raycast installation while preserving its application
  data marker and an unrelated Brew package. Removed replaced CLI formulae and
  retained `pkgconf` because other installed Brew packages depend on it.
- Verified interactive Nushell, the Proserpina rebuild alias, Git configuration,
  and Neovim startup with the repository's pinned plugins.
- Rebooted with automatic login and restored Ghostty windows. Nushell and its
  prompt started before `/run/current-system` existed; launchd brought T3Code
  back after login.
- Entered a Devenv project through both `devenv shell` and the Codex launcher.
- Installed and ran Codex, Claude Code and OpenCode; verified successful
  launchd updates and selection of all three profile entries.
- Tested simulated Ansible links, backup creation, existing T3Code state
  preservation, repeated activation and rejection of conflicting local files.
- Passed the Linux flake check and Othinus build. Othinus's system derivation
  remained identical to the pre-migration baseline.

The work Mac runs macOS 27 and was not activated. GUI checks used the image's
initialized account renamed to `rafael`. Account sign-in, work credentials,
VPN connectivity, OrbStack's nested virtualization, and each application's full
workflow were not tested.
