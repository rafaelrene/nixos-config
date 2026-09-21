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
| `nixpkgs-unstable` | Newer Discord, IINA, Mailspring, OrbStack, Proton Pass, Raycast, Shottr, Slack, Yaak, Devenv, Graphite and Pi. |
| `brew-nix` and `brew-api` | Native Mac releases for Amethyst, Anytype, Ente Photos/Auth, Gifox, ONLYOFFICE, Proton Drive, RustDesk, Standard Notes, Superwhisper, Tailscale, Telegram, Thaw, Chromium, WhatsApp and Zentty. |
| Upstream flakes | Zen, Helium and Try; independent profiles handle T3Code and agent tools. |
| `vendor-sources.json` | Complete Google Drive and Viber app payloads with explicit versions and hashes. |

FreeTube, Ghostty, Signal and Teams retain their tested stable Nixpkgs
packages. brew-nix reads cask metadata and produces Nix derivations; it never
runs Brew. Thaw uses the newer cask release because even unstable Nixpkgs
currently trails it. Telegram remains the native Mac client. Filen uses the
signed vendor bundle through brew-nix; the Nixpkgs launcher uses Electron's
generic data directory instead of the vendor's application identity.

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

[nixpkgs-multiverse](https://github.com/fzakaria/nixpkgs-multiverse) was considered.
It indexes existing Nixpkgs revisions for version selection and recovery; it
does not supply missing Mac packages. A stable base, one unstable input and
brew-nix cover the current requirements without another resolver.

## Prerequisites and activation

Validate in a disposable macOS VM before applying to the work Mac. Creating a
VM on the work Mac does not authorize switching the host's configuration.

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

The following commands change the target system. During migration testing,
run them only inside the disposable VM. First activation:

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

After Nix packages are installed, activation uninstalls only the named
Brew apps, fonts and CLI tools replaced by Nix, including the old T3Code cask.
Agent cleanup waits until the rolling Nix profile contains each replacement.
Formulae required by other installed Brew packages remain. Cleanup never uses
`--zap`, `--force`, autoremove or global Brew cleanup: application data and
unrelated Brew packages remain. Homebrew may request Automation permission to
remove an application's login items. Launch the Nix copies from
`/Applications/Nix Apps`. Homebrew is consulted only for this migration cleanup,
which is skipped on clean machines without Brew. Unrelated legacy Brew packages
are neither removed nor updated by this configuration.

nix-darwin installs real app bundles. Google Drive and RustDesk also have
compatibility links at their vendor's expected top-level `/Applications` paths;
activation refuses unrelated files at those paths. Google Drive's installed
mount helper receives its vendor-required root ownership and setuid permission.
Tailscale/Proton Drive automatic Sparkle updates and Google Drive's vendor updates
are disabled so these applications follow `nup`/`nups`.

T3Code's server and desktop are built from the same official nightly release and
staged together in `~/.local/state/nix/profiles/t3code`. A matching bootstrap pair
is included in the system closure, so startup does not wait for an online update.
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
is shared, while project trust paths belong to this Mac.

On a fresh installation, `~/.t3` links back to the XDG T3Code directory. macOS
restores the signed upstream desktop directly at login, potentially before
launchd supplies `T3CODE_HOME`. This compatibility link keeps its saved connection
and disabled embedded server intact during restoration.

Existing SSH private keys are neither imported nor decrypted by the Mac module.
A fresh VM can test client configuration without work credentials. Existing Zsh
files, local secrets and shell history are left untouched. Switching shells does
not translate Zsh-only secret exports into Nushell; project secrets should stay
in their existing external secret storage or project environment.

`~/.local/share/raycast/scripts` contains the unchanged Raycast launchers. Select
that directory in Raycast’s Script Commands settings instead of `~/.web-apps`.
An existing Ansible link is left untouched; a link installed by an earlier
nix-darwin generation is retired automatically. The launchers still use Chromium. The imported Zentty helpers still explicitly open
Zsh panes; the default login shell and Ghostty use Nushell. The old custom NvChad
configuration is not imported; the selected editor configuration is LazyVim.

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

Building and activating the Darwin closure requires macOS. Use an isolated
[Tart VM](https://tart.run/quick-start/) with no host-home mount or forwarded
agent credentials. Test a clean installation, repeated activation, a simulated
Ansible home, conflict rejection, Nushell startup, application discovery and the
launchd agent updater. Do not treat evaluation alone as an end-to-end test.

### Retained testing VM

Keep this environment between testing sessions. Delete the VM, downloaded image
and testing tools only when Rene explicitly requests cleanup. Stop the VM when
idle to release CPU and memory; retain its disk and the image cache.

- Host: `rafael@macbookpro.lan`. Use this Mac only to run Tart, never to activate
  Proserpina's configuration.
- Host working directory: `/Users/rafael/Library/Caches/proserpina-vm-testing`.
- Tart executable: `tool/tart.app/Contents/MacOS/tart` under that directory.
- Set `TART_HOME` to that directory's `tart` subdirectory and
  `TART_NO_AUTO_PRUNE=1` for every Tart command.
- VM name: `proserpina-test`; source image:
  `ghcr.io/cirruslabs/macos-tahoe-base:latest`.
- Linux SSH configuration:
  `/home/raf/.local/state/proserpina-vm-testing/ssh_config`.
  It defines `proserpina-work-mac` and `proserpina-vm`.
- Start with `tart run proserpina-test --no-graphics --no-audio --no-clipboard
  --vnc-experimental`. Keep its output private: it contains the temporary VNC
  password. This virtual console supports macOS's protected permission dialogs.
- Forward local SSH port `22229` to port `22` at the guest's current
  `tart ip proserpina-test` address. Forward local VNC port `15929` to the host's
  temporary VNC port printed by Tart. Both forwards go through the work Mac.
  Recreate them after restarting the VM; addresses and ports can change.
  Do not mount the host home or forward agents.

Created on 2026-09-20 with macOS 26.6.2, two CPU cores, 4 GiB RAM and a 120 GB
virtual disk. The initialized account is renamed to `rafael`; Nix and the
checkout are installed inside the guest. Reuse `proserpina-test` for the
remaining migration work rather than cloning the image again.

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
