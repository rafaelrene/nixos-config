# Proserpina

Apple Silicon, user `rafael`, home `/Users/rafael`, checkout
`/Users/rafael/code/.personal/nixos-config`. The flake output is
`darwinConfigurations.Proserpina`.

## Scope

| Feature            | macOS configuration                                                                                                    |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Shell and runtimes | Nushell login shell, Bash/sh, Starship, zoxide and Devenv.                                                             |
| Editor             | Shared LazyVim configuration, theme, and private Mason installer runtimes.                                             |
| Git                | Shared configuration, Delta theme, ignores, and branch helpers.                                                        |
| Terminal           | Ghostty from Nix, shared palette, Mac Option key and quick-terminal settings.                                          |
| Desktop apps       | Nixpkgs, upstream flakes and brew-nix; no Homebrew installation required.                                              |
| Window management  | OmniWM scrolling columns, Option and Caps Lock shortcuts, and nine workspaces; workspace 1 is Work.                    |
| Agents             | Shared rules, skills and themes; Codex, Claude Code and OpenCode use an independent rolling Nix profile.               |
| Mac helpers        | Chromium web launchers for Raycast.                                                                                    |
| SSH                | Shared client configuration and all four managed keys; Remote Login trusts `proserpina.pub`. Uses the macOS SSH agent. |

The Mac does not import Niri, systemd services, the Linux SSH server, snapshots,
or Othinus's network exposure rules. A separate launchd service runs T3Code on
`127.0.0.1:3773`; its desktop is a client. Tailscale uses the native Mac app.

## Package sources

Applications live in [modules/applications](../../modules/applications/README.md).
The shared profile selects common apps; Proserpina adds its Mac apps. Each app
owns its package source, overrides, settings, and platform integration. The
host keeps its own username, home directory, checkout, and Darwin Nixpkgs pin.

| Source                                                             | Purpose                                                                                   |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| `nixpkgs` / `nixos-26.05`                                          | Othinus; pinned separately from the Mac base.                                             |
| `nixpkgs-darwin` / `nixpkgs-26.05-darwin` and nix-darwin 26.05     | Stable Mac base, shell and development environment.                                       |
| `nixpkgs-unstable`                                                 | Selected desktop apps and development tools, including Devenv; OmniWM's packaging recipe. |
| `brew-nix` and `brew-api`                                          | Native Mac app releases, including MongoDB Compass, packaged as Nix derivations.          |
| Upstream flakes                                                    | Zen and Helium; independent profiles handle T3Code and agent tools.                       |
| [Vendor sources](../../modules/system/updates/vendor-sources.json) | Google Drive, OmniWM and Viber app archives with explicit versions and hashes.            |

FreeTube, Ghostty, and mpv use stable Nixpkgs packages. mpv is the media player
on both hosts. Homebrew is disabled;
brew-nix reads cask metadata without running Brew.

Thaw uses the signed **3.0.0-alpha.7** release for macOS 27, with its
update channel set to `alpha`. Its archive and checksum are pinned in
`modules/applications/thaw/default.nix`; update that override for later alpha releases.
The alpha override is required for macOS 27 support. Telegram uses the native
Mac client. Filen uses the signed vendor bundle to preserve its application
identity and data location.

MongoDB Compass updates through the cask input. `bkt` uses official release
binaries with the public OAuth client configuration. Update its version and
platform hashes in
[package.nix](../../modules/applications/bkt/package.nix).

Raycast requires version 2.5.2 or later for its database schema. The package
uses the signed upstream 2.5.2 archive when Nixpkgs is below that minimum;
newer Nixpkgs versions take precedence automatically.
Do not downgrade Raycast or reset its databases. After updating its bundle,
verify Command-Space and ensure its login item points to
`/Applications/Nix Apps/Raycast.app`.

Before replacing applications, activation disables Raycast's user updater
(`com.raycast.macos.updater`) and privileged updater
(`com.raycast.macos.updater.daemon`) with `launchctl`, then unloads either helper
if registered. The disabled state persists across reboots and leaves the signed
app bundle intact. Raycast can still download updates or show update prompts;
install app updates through `nups`. Extension updates remain managed by Raycast.
Removing this configuration does not re-enable the helpers: restoring vendor
updates also requires `launchctl enable user/<uid>/com.raycast.macos.updater`
(substitute the numeric UID from `id -u`) and
`sudo launchctl enable system/com.raycast.macos.updater.daemon`.

Shottr requires confirmation before installing its own updates. Leave those
prompts unconfirmed and update through `nups`; no supported preference to disable
its update prompts is configured.

Slack, Teams and Signal use cask metadata. Teams uses Nixpkgs' extraction of
only the app payload, excluding Microsoft AutoUpdate. Their versions advance
through `nup`/`nups`. Activation writes Slack's `AutoUpdate = false` policy to
`/Library/Managed Preferences/com.tinyspeck.slackmacgap.plist`. Slack requires
an enforced policy and ignores this key in ordinary user preferences. Quit and
reopen Slack after activation so it reads the policy. Its app bundle remains
signed and unmodified.

Google Drive's package extracts only the Apple Silicon app, excluding Google's
updater and document shortcuts. Viber uses its complete app payload, not the
small online installer distributed by its cask. Both vendors overwrite their
download URLs, so `nup` downloads and inspects them before atomically updating
the version/hash manifest. Rebuilding a pinned version requires its download
in the Nix store or a cache if the vendor URL no longer serves those bytes.

Viber's package omits the updater manifest outside its signed resources and
verifies the bundle signature during the native build. For Discord, activation
installs a pinned manifest generated from Nixpkgs' host/module versions and
hashes and enables it without
replacing other Discord settings. Discord downloads its initial runtime modules
using that manifest; subsequent version changes follow `nup` and a rebuild.
Its signed app bundle remains intact, including when opened from Finder.

Zen associates default profiles with the installation path. Keep its installed
path at `/Applications/Nix Apps/Zen Browser (Beta).app` so rebuilds retain the
existing profile association. If a path change selects a fresh profile, quit
Zen and check `profiles.ini` and `installs.ini` before changing browser data.

## Window management

Nix installs OmniWM's signed app, links a generated
`~/.config/omniwm/settings.toml`, and starts it through a user launchd agent.
Edit `modules/applications/omniwm/settings.nix` and rebuild; the GUI cannot save over
the Nix-store configuration. OmniWM's own update checks are disabled.

All nine workspaces use independent horizontal scrolling columns. Workspace 1
is labelled **Work**. App rules assign Ghostty, T3 Code, Helium, Slack and Teams
to workspace 1, WhatsApp, Viber and Signal to workspace 8, and Zen to workspace 9.
System Settings is tiled on the current workspace with a 50% initial container
span. These rules are declared in
`modules/applications/omniwm/settings.nix`; GUI edits do not survive an OmniWM
restart. Move existing columns between workspaces with the shortcuts below.

By default, new columns use the full available width. Width cycling follows Othinus:
⅓, ½, ⅔, full. Focused columns center on overflow; gaps are 2 points and the
focus border uses the shared theme. Animations are disabled. OmniWM's menu bar
item names the current workspace. Hold Option for 200 ms to show the workspace bar
with each workspace's apps, including floating windows. It overlays the top of
windows so they keep the full height, and stays visible while holding Option +
Shift to move windows.
The bar deduplicates app icons and hides empty workspaces.
OmniWM's Infinite Loop Navigation is enabled for the Niri layout.

Arrow navigation and workspace numbers use **Option**; add **Shift** to move
columns or windows. Vertical arrows are reversed: Down acts upward and Up acts
downward, including when moving with Shift. These shortcuts take precedence
over applications' Option + arrow text navigation and selection.

Other window shortcuts use **Caps Lock** held as OmniWM's **Hyper** trigger,
which sends Control + Option + Command. Shift remains separate for alternate
actions. Plain Control shortcuts, including Neovim's Control + O, reach apps.
Nix remaps Caps Lock to F18, and OmniWM uses F18 as its trigger: tapping it does
nothing and never toggles capitals. Unassigned Caps chords reach apps with the
Hyper modifiers. A physical F18 key also acts as Hyper.

| Shortcut                    | Action                                                          |
| --------------------------- | --------------------------------------------------------------- |
| Option + Enter              | Open a fresh Ghostty window through skhd                        |
| Option + left/right         | Focus columns                                                   |
| Option + down/up            | Focus windows upward/downward, then the adjacent workspace      |
| Option + Shift + left/right | Move the whole column                                           |
| Option + Shift + down/up    | Move the window upward/downward, then to the adjacent workspace |
| Option + 1–9                | Switch workspace; 1 is Work                                     |
| Option + Shift + 1–9        | Move the focused column to a workspace                          |
| Caps + Page Up/Down         | Previous/next workspace                                         |
| Caps + Shift + Page Up/Down | Move the column to the previous/next workspace                  |
| Option + 0                  | Overview across workspaces                                      |
| Caps + R / Caps + Shift + R | Cycle column width forward/backward                             |
| Caps + minus/equal          | Decrease/increase column width by 10%                           |
| Caps + F                    | Toggle full-width column                                        |
| Caps + Shift + F            | Toggle managed fullscreen without entering a native Space       |
| Caps + V                    | Toggle floating                                                 |
| Caps + Q                    | Close the focused window                                        |
| Caps + [ / ]                | Consume a window into the column / expel it                     |

On the built-in keyboard, Fn+up/down supplies Page Up/Down. Three-finger
horizontal swipes scroll columns; three-finger vertical swipes change
workspaces. Four-finger up/down opens/closes overview. Nix disables the
conflicting macOS trackpad gestures. Option + Command + mouse drag moves tiled
windows; Option + Command + right-drag resizes them. Mouse modifiers cannot be
side-specific, and Control-click is right-click.

Nix owns macOS's keyboard shortcut list (`com.apple.symbolichotkeys`). It
disables Mission Control's Control+arrow shortcuts, desktop switching, and
Spotlight's Command+Space so Raycast can use it. Shortcuts not listed in
`modules/applications/omniwm/default.nix` revert to macOS defaults. macOS
applies changes at the next login.

Keep one native macOS desktop and use the nine OmniWM workspaces. OmniWM only
manages windows on the current native desktop, so a window on another desktop
is unreachable.
Do not assign apps to desktops through the Dock's Options menu. These are
configured workspaces, not Niri's automatically added/removed empty workspaces.
OmniWM accepts one binding per action, so this configuration uses Othinus's
arrows rather than also duplicating H/J/K/L. Workspace reordering and Niri's
modifier+wheel workspace switching are not mapped.

Option+Enter uses skhd to open the home directory in a fresh Ghostty window,
reusing the running application so repeated presses keep one Dock icon. It also
launches Ghostty when closed, without restoring saved windows. Ghostty's
`macos-dock-drop-behavior = new-window` setting makes folder-open requests create
windows rather than tabs; this also applies to folders dropped onto its Dock icon.
`modules/applications/skhd/default.nix` configures nix-darwin's native skhd service,
which installs the package, writes `/etc/skhdrc`, and runs a user launchd agent.
Grant skhd Accessibility permission in System Settings after the first rebuild,
then log out and back in to restart it. Secure Keyboard Entry must be disabled
for skhd to receive shortcuts. Caps+Enter does not launch applications.

The declared “Displays have separate Spaces” setting requires a logout/login
after it changes. Launchd starts `/Applications/Nix Apps/OmniWM.app`.
Grant it Accessibility and Input Monitoring in the macOS permission dialog,
plus Screen Recording for overview
thumbnails. Return to OmniWM's permission window to continue. These macOS
permissions cannot be pre-granted by Nix. Leave OmniWM's separate “Start at
Login” option off because launchd already owns startup.

The settings defaults in `modules/applications/omniwm/defaults.json` come
from [OmniWM v0.7.3's canonical settings model](https://github.com/OmniNull/OmniWM/blob/v0.7.3/Sources/OmniWM/Core/Config/CanonicalTOMLConfig.swift).
All app rules are declared in `settings.nix`.
`nup` checks GitHub's latest stable OmniWM release independently of the version
in Nixpkgs. The vendor-source manifest records its version, permanent signed app
archive URL and SHA-256 checksum; `ns` builds from that recorded release.
There is no version fallback or version assertion. Upstream requires
every hotkey action, even unassigned ones; if a release changes that schema,
update the defaults snapshot and generated settings to match.

The launch agent includes the package's Nix store path in `OMNIWM_PACKAGE`.
This makes its plist change when the package changes, so `ns`/`nups` reload
OmniWM automatically while retaining its stable application path for macOS
permissions. `nup` alone updates package sources; `ns` installs them.

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
and `nups` for updating then switching. Shells use `en_US.UTF-8` for `LANG` and
`LC_ALL` so inherited macOS locale identifiers do not cause POSIX command warnings.
Open a new shell after switching to load changed environment settings.
`nup` refreshes stable Darwin and unstable
Nixpkgs, nix-darwin, shared Rust/browser inputs and brew-nix/cask metadata.
It refreshes the Google Drive/OmniWM/Viber manifest, stages T3Code (activating it immediately with `nup`, or after the switch with `nups`), and
updates all three rolling agent packages. Nix system packages take effect after `ns` or
`nups`. Updating shared Rust and browser pins affects Othinus's next rebuild too.
Failures stop the command and are reported; a failed update does not switch the
system. OmniWM restarts automatically when its package changes during a switch.
Close and reopen other desktop applications to use updated versions.

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
a version/hash edit.

Proton Drive and its File Provider must run from the same Nix app bundle. If
macOS reports an installation-path mismatch, quit Proton Drive and reopen
`/Applications/Nix Apps/Proton Drive.app`. Do not delete File Provider data or
sign out to fix a path mismatch.

T3Code's server and desktop are built from the same official nightly release and
staged together in `~/.local/state/nix/profiles/t3code-staged`; the running pair
uses `~/.local/state/nix/profiles/t3code`. A matching bootstrap pair
is included in the system closure, so startup does not wait for an online update.
A listener on port 3773 blocks activation unless the nix-darwin T3Code service
is already registered. Bitbucket uses `T3CODE_BITBUCKET_EMAIL` and
`T3CODE_BITBUCKET_API_TOKEN` in the server environment, outside this repository.
The unmanaged `local.t3code.bitbucket-env` launch agent references a missing
Keychain item; persistent credential loading needs repair before restarting
the authenticated server (see [TODO](../../TODO.md)).
Launchd starts the server at login, restarts it on failure, checks for updates
every three hours, and activates staged releases at 04:00. `ns` and explicit
updates request the same coordinated activation: close running clients, activate
the matching server and desktop, check server readiness, and reopen a previously
open client. Activation waits for launchd to finish removing the old server
before promoting the profile. `t3-activate`, `ns` and `nups` wait for activation
and report failures; launcher failures also send a native notification and write
to the desktop log. Failed downloads leave both profiles unchanged. See the
[T3 Code guide](../../modules/applications/t3code/README.md) for activation logs,
failure handling, and direct rebuild commands. Open
**T3 Code** in `/Applications/Nix Apps` for the client. Its launcher disables
the embedded server and application self-updater while preserving other native
preferences. Pair it with the local server using `t3 pair`; the connection is
saved by the client. The server uses the shared palette and Devenv-aware agent
wrappers. Logs live in `~/.local/state/nix-darwin/t3code*.log`.

The native desktop uses an imported custom theme. After changing the central
palette, reimport `~/.local/share/t3code/userdata/themes/othinus.json` in the
desktop's theme settings.

Devenv is the project runtime manager. Declare language versions and project
tools in each project's `devenv.nix`. The shared Nushell direnv hook loads that
environment automatically in T3 worktrees; regular checkouts require `direnv allow`.
Agent wrappers use `devenv shell -- <command>` when needed. See the
[project environment guide](../../modules/applications/devenv/README.md).
Bash/sh and Nushell are the workstation shells. Compilers, Node and other
language runtimes come from project environments or application-private
dependencies. The login shell and Ghostty use
`/nix/var/nix/profiles/system/sw/bin/nu`, which
remains available before boot activation recreates `/run/current-system`.

The agent updater stages releases at login and every three hours through launchd;
a separate job activates them at 04:00. Failed checks retry after at least five
minutes, including when Nix is still starting. `nup` and `nups` check and activate
immediately. Logs are `~/.local/state/nix-darwin/agents-update.log` and
`agents-activation.log`. The first successful check initializes a missing active
profile. The shared Nix launchers take
precedence in Nushell's PATH and enter the project's Devenv environment before
starting an agent.
The Mac trusts Numtide's signed binary cache through its system configuration.
The [agent updater](../../modules/applications/coding-agents/README.md) uses
Codex and Claude's latest stable publisher releases, verified against their
checksums. Numtide supplies OpenCode and Claude's platform integration. All three
agents install as one generation without applying upstream flake settings.

## User files and state

Activation checks all declared user-file destinations before changing any of
them. It replaces only matching or previously recorded managed links. A real
file, unrelated symlink, or unmanaged parent-directory symlink aborts activation
with its path. Reconcile that destination before retrying.

The installation manifest lives at `~/.local/state/nix-darwin/links.json`;
stale links are removed only while they still point to their recorded target.

Agent state uses XDG directories. When `~/.codex`, `~/.claude`,
or `~/.t3` contains state, its XDG counterpart links to that directory.
If both locations contain separate directories, activation stops rather than
choosing one. Agent settings stored as real files are subject to the same
conflict checks as other configuration.
The Pi state alias remains recognized so stale managed links can be removed
without changing existing Pi data; the Pi package is not installed.
Codex's editable host settings live in `hosts/proserpina/codex.toml`; its theme
is shared, while project trust paths belong to this Mac. Claude's Mac preferences
live in `hosts/proserpina/claude.json`. Never copy credentials into the checkout.

On a fresh installation, `~/.t3` links back to the XDG T3Code directory. macOS
restores the signed upstream desktop directly at login, potentially before
launchd supplies `T3CODE_HOME`. This compatibility link keeps its saved connection
and disabled embedded server intact during restoration.

An interactive rebuild decrypts the shared SSH bundle when keys need updating,
installing `personal`, `bitbucket_work`, `othinus`, and `proserpina` in `~/.ssh`.
Unchanged keys need no prompt; differing existing keys are backed up before
replacement. Cancelling or entering a wrong archive passphrase aborts activation
before replacing keys. Builds and `darwin-rebuild check` do not provision keys.
See the [SSH guide](../../modules/applications/openssh/README.md) for recovery and rotation.
The SSH client config links to a read-only Nix-store copy, since OpenSSH rejects
a group-writable checkout file even through a symlink. Editing
`modules/applications/openssh/hosts.config` takes effect after `ns` on the Mac and
immediately on Othinus, whose SSH config includes it from the checkout.
Keep project secrets in external secret storage or the project environment.

`modules/applications/webapps/darwin-apps.json` declares the Chromium web launchers by name
and URL. Nix generates individual launcher links in the real directory
`~/.local/share/raycast/scripts`. Select that directory once in Raycast's Script
Commands settings and remove obsolete script folders. Keep the directory itself
real: the macOS folder picker resolves directory symlinks to a fixed store path.
Rebuild after changing the list. Launchers use the
Nix-managed Chromium bundle under `/Applications/Nix Apps`.

Run `nav` or press **Space Space** in Nushell's normal mode to pick a project,
Home, a configuration folder, or an SSH host with fzf. Selection changes directory
or starts SSH in the current terminal. See the
[shared guide](../../modules/shell/scripts/README.md#destination-picker) for
discovery rules and removal of any retained Raycast destination shortcut.

Nushell uses Vi editing. In normal mode, **Space Space** opens `nav`, **Space n**
opens `git nav`, and **Space p** opens `project-run`. See the
[shell leader guide](../../modules/shell/scripts/README.md#shell-leader).

macOS controls application sign-in and privacy permissions. For example,
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

For Raycast updater changes, confirm `launchctl print-disabled user/<uid>` and
`launchctl print-disabled system` report the two updater helpers as disabled
after an authorized activation. Verify neither helper remains loaded, then test
Command-Space and an extension. Check that Raycast's update action cannot replace
the app; do not approve re-enabling its helpers. Repeat after relaunch and reboot.
Compare the installed version with the Nix package before switching to avoid
replacing a newer self-updated app with an older package.

Use native Mac validation. For OmniWM updates,
decode the generated settings against the matching upstream schema, check the
app signature and launchd plist, and verify shortcuts and window management
after an authorized switch. An IPC response alone does not prove input services
are running.

For skhd changes, inspect the generated `/etc/skhdrc` and validate its launchd
plist with `plutil -lint`. After an authorized switch and Accessibility setup,
press Option+Enter from another application with Ghostty closed, then repeat
with a Ghostty window already open. Each press should open one fresh terminal in
the home directory without restoring saved windows or focusing an existing
window. Repeated presses must reuse the same application process and Dock icon.

For `nav` changes, validate the generated Nushell configuration and module.
After an authorized switch, test the command and Space Space at a fresh
Nushell prompt: search, change directory, cancel, connect through SSH, and exit
back to the local shell. Check that the shortcut preserves partially typed input
and does not open another window. Repeat in Nushell on Othinus.

For shell leader changes, test all three sequences in normal mode on each host,
including cancellation and preserving partially typed input. Verify spaces still
insert in insert mode and Neovim receives its own Space leader bindings.
