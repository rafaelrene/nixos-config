# Proserpina

Apple Silicon, user `rafael`, home `/Users/rafael`, checkout
`/Users/rafael/code/.personal/nixos-config`. The flake output is
`darwinConfigurations.Proserpina`.

## Scope

| Feature            | macOS configuration                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Shell and runtimes | Nushell login shell, Starship, zoxide, Devenv and Node 24. Existing Mise installations remain untouched.                        |
| Editor             | Shared LazyVim configuration, theme, and private Mason installer runtimes.                                                      |
| Git                | Shared configuration, Delta theme, ignores, and branch helpers.                                                                 |
| Terminal           | Ghostty from Nix, shared palette, Mac Option key and quick-terminal settings.                                                   |
| Desktop apps       | Nixpkgs, upstream flakes and brew-nix; no Homebrew installation required.                                                       |
| Window management  | OmniWM scrolling columns, Caps Lock shortcuts, and nine workspaces; workspace 1 is Work.                                        |
| Agents             | Shared rules, skills and themes; Codex, Claude Code and OpenCode use an independent rolling Nix profile. Pi comes from Nixpkgs. |
| Mac helpers        | Existing Raycast web launchers and Zentty helpers imported unchanged.                                                           |
| SSH                | Shared client configuration and all four managed keys; Remote Login trusts `proserpina.pub`. Uses the macOS SSH agent.          |

The Mac does not import Niri, systemd services, the Linux SSH server, snapshots,
or Othinus's network exposure rules. A separate launchd service runs T3Code on
`127.0.0.1:3773`; its desktop is a client. Tailscale keeps the native Mac app.

## Package sources

The system uses flake inputs rather than imperative `nix-channel` subscriptions:

| Source                                                         | Purpose                                                                                                                                                                                                               |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `nixpkgs` / `nixos-26.05`                                      | Othinus, unchanged by Mac package updates.                                                                                                                                                                            |
| `nixpkgs-darwin` / `nixpkgs-26.05-darwin` and nix-darwin 26.05 | Stable Mac base, shell and development environment.                                                                                                                                                                   |
| `nixpkgs-unstable`                                             | Newer Discord, IINA, Mailspring, OmniWM, OrbStack, Proton Pass, Raycast, Shottr, Yaak, Devenv, Graphite and Pi.                                                                                                       |
| `brew-nix` and `brew-api`                                      | Native Mac releases for Anytype, Ente Photos/Auth, Gifox, Microsoft Teams, ONLYOFFICE, Proton Drive, RustDesk, Signal, Slack, Standard Notes, Superwhisper, Tailscale, Telegram, Thaw, Chromium, WhatsApp and Zentty. |
| Upstream flakes                                                | Zen, Helium and Try; independent profiles handle T3Code and agent tools.                                                                                                                                              |
| `vendor-sources.json`                                          | Complete Google Drive and Viber app payloads with explicit versions and hashes.                                                                                                                                       |

FreeTube and Ghostty retain their tested stable Nixpkgs
packages. brew-nix reads cask metadata and produces Nix derivations; it never
runs Brew. Thaw uses the signed **3.0.0-alpha.7** release for macOS 27, with its
update channel set to `alpha`. Its archive and checksum are pinned in
`modules/darwin/packages.nix`; update that override for later alpha releases.
The stable cask does not support macOS 27. Telegram remains the native Mac
client. Filen uses the signed vendor bundle through brew-nix; the Nixpkgs
launcher uses Electron's generic data directory instead of the vendor's
application identity.

Raycast has a 2.5.2 minimum: the Mac's databases already use that
release's schema, which 2.4.1 cannot open. Until the unstable input catches up,
the package uses the signed upstream 2.5.2 archive and checksum. Newer Nixpkgs
versions take precedence automatically. Compare the running app version before
replacing self-updated applications; a Brew receipt can report an older version.
Do not downgrade Raycast or reset its databases. After replacing its bundle,
verify Command-Space and ensure its login item points to
`/Applications/Nix Apps/Raycast.app`.

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

Zen associates default profiles with the installation path. Keep its installed
path at `/Applications/Nix Apps/Zen Browser (Beta).app` so rebuilds retain the
existing profile association. If a path change selects a fresh profile, quit
Zen and check `profiles.ini` and `installs.ini` before changing browser data.

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

| Shortcut                    | Action                                                            |
| --------------------------- | ----------------------------------------------------------------- |
| Caps + left/right           | Focus columns                                                     |
| Caps + up/down              | Focus windows in the column, then the adjacent workspace          |
| Caps + Shift + left/right   | Move the whole column                                             |
| Caps + Shift + up/down      | Move the window within its column, then to the adjacent workspace |
| Option + 1–9                | Switch workspace; 1 is Work                                       |
| Option + Shift + 1–9        | Move the focused column to a workspace                            |
| Caps + Page Up/Down         | Previous/next workspace                                           |
| Caps + Shift + Page Up/Down | Move the column to the previous/next workspace                    |
| Caps + O                    | Overview across workspaces                                        |
| Caps + R / Caps + Shift + R | Cycle column width forward/backward                               |
| Caps + minus/equal          | Decrease/increase column width by 10%                             |
| Caps + F                    | Toggle full-width column                                          |
| Caps + Shift + F            | Toggle managed fullscreen without entering a native Space         |
| Caps + V                    | Toggle floating                                                   |
| Caps + Q                    | Close the focused window                                          |
| Caps + [ / ]                | Consume a window into the column / expel it                       |

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

The declared “Displays have separate Spaces” setting requires a logout/login
after it changes. Launchd starts `/Applications/Nix Apps/OmniWM.app`.
Grant it Accessibility and Input
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
authorized live switch; see [validation](#validation).

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

Writing Proton Drive's sandboxed
updater preferences requires Full Disk Access; sudo alone does not grant it.
On macOS 27, the privacy log attributes nix-darwin's `launchctl asuser` write to
the Nix-store `bash` running activation. Enable that **bash** entry under System
Settings > Privacy & Security > Full Disk Access. Terminal's permission alone
is insufficient for this process chain. If `bash` is absent, add the exact Nix
Bash binary named by the activation script's shebang. A Bash package update can
change that path and require granting access again. Keep this access available
for subsequent rebuilds that write the same preferences.

nix-darwin installs real app bundles in `/Applications/Nix Apps`. Google Drive
and RustDesk also have compatibility links at their vendor's expected top-level
`/Applications` paths. Activation rejects unmanaged files at those paths before
changing applications. Google Drive's installed mount helper receives its
vendor-required root ownership and setuid permission.

Tailscale, Proton Drive and Thaw automatic Sparkle updates and Google Drive's
vendor updates are disabled so Nix controls their installed versions.
`nup`/`nups` refreshes the normal package sources; Thaw's alpha override requires
a version/hash edit. Homebrew packages are not managed or removed by activation.

Proton Drive and its File Provider must run from the same Nix app bundle. If
macOS reports an installation-path mismatch, quit Proton Drive and reopen
`/Applications/Nix Apps/Proton Drive.app`. Do not delete File Provider data or
sign out to fix a path mismatch.

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
the Nix profile's agent commands are available. The shared Nix launchers take precedence in Nushell's PATH and
enter the project's Devenv environment before starting an agent.
The Mac trusts Numtide's signed binary cache for these packages and uses Nix's
explicit `--all` selector when upgrading the profile.

## Existing files and state

Activation checks all declared user-file destinations before changing any of
them. It replaces only matching or previously recorded managed links. A real
file, unrelated symlink, or unmanaged parent-directory symlink aborts activation
with its path. Reconcile that destination before retrying; activation does not
adopt Ansible links or create migration backups.

The installation manifest lives at `~/.local/state/nix-darwin/links.json`;
stale links are removed only while they still point to their recorded target.

Existing `~/.codex`, `~/.claude`, `~/.pi/agent`, and `~/.t3` directories remain
where they are. Their XDG counterparts alias them, preserving credentials and sessions.
Clean installations create XDG directories directly. If both locations already
exist, activation stops rather than choosing one. Agent settings stored as real
files are subject to the same conflict checks as other configuration.
Codex's editable host settings live in `hosts/proserpina/codex.toml`; its theme
is shared, while project trust paths belong to this Mac. Claude's Mac preferences
live in `hosts/proserpina/claude.json`, preserving its model, permission mode,
editor and notification settings. Never copy credentials into the checkout.

On a fresh installation, `~/.t3` links back to the XDG T3Code directory. macOS
restores the signed upstream desktop directly at login, potentially before
launchd supplies `T3CODE_HOME`. This compatibility link keeps its saved connection
and disabled embedded server intact during restoration.

An interactive rebuild decrypts the shared SSH bundle when keys need updating,
installing `personal`, `bitbucket_work`, `othinus`, and `proserpina` in `~/.ssh`.
Unchanged keys need no prompt; differing existing keys are backed up before
replacement. Cancelling or entering a wrong archive passphrase aborts activation
before replacing keys. Builds and `darwin-rebuild check` do not provision keys.
See the [SSH guide](../../modules/services/ssh/README.md) for recovery and rotation.
The SSH client config links to a read-only Nix-store copy, since OpenSSH rejects
a group-writable checkout file even through a symlink. Editing
`modules/services/ssh/hosts.config` takes effect after `ns` on the Mac and
immediately on Othinus, whose SSH config includes it from the checkout. Existing Zsh
files, local secrets and shell history are left untouched. Switching shells does
not translate Zsh-only secret exports into Nushell; project secrets should stay
in their existing external secret storage or project environment.

`~/.local/share/raycast/scripts` contains the unchanged Raycast launchers. Select
that directory in Raycast’s Script Commands settings instead of `~/.web-apps`.
The launchers use Chromium. The imported Zentty helpers explicitly open
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

Use native Mac validation. For OmniWM updates,
decode the generated settings against the matching upstream schema, check the
app signature and launchd plist, and verify shortcuts and window management
after an authorized switch. An IPC response alone does not prove input services
are running.
