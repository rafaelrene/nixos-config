# T3 Code updates

Both machines use matching official nightly server and desktop downloads. The
server package runs the desktop's JavaScript server bundle with Nix-managed
Node 24 and the CLI archive's native runtime dependencies and resource monitor.
The signed desktop application remains unmodified. The shared Nix recipes in
`package/` accept a version and download hashes. `release.json`
pins the default packages and Proserpina's offline bootstrap bundle. The flake
exposes `packages.<system>.t3code` and a parameterized
`legacyPackages.<system>.t3codeForRelease` using those same recipes.

The installed updater uses an immutable snapshot of this repository, including
its locked Nix inputs. A system rebuild installs changes to recipes and their
dependencies. Nightly version changes do not require a system rebuild.

## Nushell setup actions

Both services keep Nushell as their integrated terminal shell. The server package
applies `package/nushell-completion.patch` to its separate copy of the JavaScript
bundle. This adds Nushell detection and a native `try`/`catch` completion wrapper:
successful commands report 0, failed external commands report their exit code,
and Nushell errors report 1. T3 Code can finish the setup card and release a
waiting agent without changing project actions or shell configuration.

The patch applies with no context fuzz. If a nightly changes the patched code,
the package build fails and the rolling profile retains its installed generation.
Review the patch when updating the package recipe; remove it once the official
server supports Nushell completion. Until then, keep the JavaScript server,
native dependencies and desktop on the same release. Setup commands must use
valid Nushell syntax, and value-producing Nushell expressions should explicitly
`print` output because the completion wrapper ends its success block with 0.

`package/nushell-hidden-setup.patch` starts setup terminals with Nushell's
`--execute` option. It installs a one-time hook after the configured pre-prompt
hooks, preserving direnv loading, and runs the action before the line editor
requests a cursor position. Setup therefore runs with the terminal hidden.
The hook removes itself before running; opening the terminal afterward gives
the normal Nushell prompt. Retrying setup starts a fresh Nushell process.
Completion observation starts before spawning so fast actions are not missed.

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

## Bitbucket authentication

On Othinus, the server reads `~/.local/share/t3code/bitbucket.env` at startup.
This optional systemd environment file supplies `T3CODE_BITBUCKET_EMAIL` and
`T3CODE_BITBUCKET_API_TOKEN`. Keep it owned by the user with mode `0600`, outside
the repository and Nix store. The token needs repository, pull request and user
read access. Restart the server after changing credentials, then use **Rescan
server environment** in **Settings → Source Control**.

Proserpina uses the same variables in its server environment. Its local
credential startup wiring needs repair; see the
[Proserpina guide](../../../hosts/proserpina/README.md).

## Rollback

Use `nix-env --profile ~/.local/state/nix/profiles/t3code --list-generations` to
inspect retained generations, and `nix-env --profile
~/.local/state/nix/profiles/t3code --rollback` to select the previous one. Then
restart the server and reopen the desktop. The profile changes both packages
together; application data is not rolled back. The next automatic check can
install the current nightly again.
