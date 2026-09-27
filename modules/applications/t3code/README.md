# T3 Code updates

Both machines use the official nightly server and desktop downloads. The shared
Nix recipes in `package/` accept a version and download hashes. `release.json`
pins the default packages and Proserpina's offline bootstrap bundle. The flake
exposes `packages.<system>.t3code` and a parameterized
`legacyPackages.<system>.t3codeForRelease` using those same recipes.

The installed updater uses an immutable snapshot of this repository, including
its locked Nix inputs. A system rebuild installs changes to recipes and their
dependencies. Nightly version changes do not require a system rebuild.

## Update flow

`update-t3code` checks npm's `t3` nightly channel, downloads both assets for that
release with `nix store prefetch-file`, and passes their hashes and the version
directly to the shared Nix bundle definition. It does not edit package recipes,
generate a flake, or maintain a Git repository. Both packages must build before
Nix changes `~/.local/state/nix/profiles/t3code`.

The generation contains its version and hashes in `share/t3code/release.json`.
When the version is unchanged, the updater reuses those hashes and evaluates the
bundle's store path. It skips building and installing an identical generation,
but still applies changes to package recipes when their resulting bundle differs.
An older generation without this metadata is packaged once through the new
updater, without changing the profile until the bundle succeeds.

Failed discovery, downloads, or builds return a failure status and leave the
installed profile unchanged. A first installation needs a successful build;
Othinus's bootstrap service skips network access if a server is already installed.
Package checks remain enabled. A successful build does not test the running
server's health or automatically roll back a failed server startup.

The updater serializes updates with
`~/.local/state/t3code-bundle-updater/update.lock`. This is the directory's only
active state; old files in that directory are unused. The updater does not
delete them or previous profile generations.

## Scheduling and manual use

Both hosts check every three hours and restart the server daily at 04:00, with
platform-specific startup and missed-run behavior. Scheduled checks stage the
new generation without restarting the running server. Reopen the desktop after
the server restarts to use the matching client.

`t3-update-now`, also called by `nup` and `nups`, runs the same updater and
restarts the server only after installing a changed generation. Failed and
unchanged updates do not restart it. If an automatic check already staged an
update, either wait for 04:00 or explicitly restart the server:

- Othinus: `systemctl --user restart t3code.service`
- Proserpina: `launchctl kickstart -k gui/$(id -u)/org.nixos.t3code` from Bash or Zsh.

Othinus logs are available through `journalctl --user -u t3code-update.service`.
Proserpina logs are in `~/.local/state/nix-darwin/t3code-update.log`.

## Rollback

Use `nix-env --profile ~/.local/state/nix/profiles/t3code --list-generations` to
inspect retained generations, and `nix-env --profile
~/.local/state/nix/profiles/t3code --rollback` to select the previous one. Then
restart the server and reopen the desktop. The profile changes both packages
together; application data is not rolled back. The next automatic check can
install the current nightly again.
