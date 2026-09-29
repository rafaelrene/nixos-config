# T3 Code updates

Both machines use matching official nightly server and desktop downloads. The
server package runs the desktop's JavaScript server bundle with Nix-managed
Node 24 and the CLI archive's native runtime dependencies and resource monitor.
Node and npm are also on the server's private `PATH` for device-tool installation
and helper processes. Existing project tools take precedence; Node is not
installed globally.
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
Nix changes `~/.local/state/nix/profiles/t3code-staged`.
The active profile, `~/.local/state/nix/profiles/t3code`, stays unchanged until
activation. Both profiles retain Nix generations for rollback.

The generation contains its version and hashes in `share/t3code/release.json`.
When the version is unchanged, the updater reuses those hashes and evaluates the
bundle's store path. It skips building and installing an identical generation,
but still applies changes to package recipes when their resulting bundle differs.
An older generation without this metadata is packaged once through the new
updater, without changing the profile until the bundle succeeds.

Failed discovery, downloads, or builds return a failure status and leave the
staged and active profiles unchanged. A first installation needs a successful build;
Othinus's bootstrap service skips network access if a server is already installed.
Package checks remain enabled. A successful build does not test the running
server's health or automatically roll back a failed server startup.

Downloads serialize through `~/.local/state/t3code-bundle-updater/update.lock`.
Promotion and desktop launches share `activation.lock`; downloads do not hold
that lock while building. `running.json` records the server's generation and PID,
and client versions are checked against the executables mapped by their processes.
The service manager remains responsible for the server process.

## Scheduling and manual use

Both hosts download every three hours and activate at 04:00. A background check
only changes the staged profile, so reopening the desktop still uses the active
server's release.

- `t3-update-now` and `nup` download and request activation, including when the
  release was already staged.
- `ns` requests activation after a successful switch, using the newly installed
  `t3-activate` command. `nups` stages during its update phase and activates after
  switching, avoiding a restart in the middle of the rebuild.
- `t3-activate` activates the staged release without checking the network. After
  a direct `darwin-rebuild switch` or `nixos-rebuild switch`, call it explicitly.
  It waits for the independent activation job and returns failure if that job
  fails, so `ns` and `nups` report activation failures in the calling terminal.
  An existing shell keeps its old `ns` definition until a fresh shell is opened.

Without a path, `ns` and `nups` rebuild the configured main checkout. To keep
testing unmerged changes, pass their worktree path on each switch. Switching
back to a checkout without these changes removes the lifecycle coordinator;
an existing shell reports that T3 Code activation was skipped.

Activation runs as an independent launchd/systemd job so restarting T3 Code
cannot terminate its own coordinator. It closes the current user's Nix T3 Code
clients, stops the managed server, promotes the staged profile, and starts the
server. On macOS, it waits up to 30 seconds for launchd to remove the old service
and for its server process to exit before promoting the profile. A shutdown
timeout leaves the active profile unchanged. It checks the service PID,
generation, and environment descriptor before reopening a previously open client.
A closed desktop stays closed. Repeated
activation skips restarting an already current server and matching client.
Activation can interrupt running agents, including at 04:00.

A client that refuses to quit aborts activation before the server changes.
A failed server startup leaves the desktop closed and reports failure; it does
not roll back application data or automatically run an older server against it.
Correct the reported failure and retry `t3-activate`. Desktop launches wait for
activation and refuse to open against an unhealthy or mismatched local server.
On macOS, LaunchServices focuses an existing client of the selected release.
Both platforms keep the desktop's embedded server and self-updater disabled.

Inspect activation results with `journalctl --user -u t3code-restart.service` on
Othinus or `~/.local/state/nix-darwin/t3code-activation.log` on Proserpina.
Download logs use `t3code-update.service` and `t3code-update.log` respectively.
Desktop output is in `~/.local/state/t3code-bundle-updater/desktop.log`.
Launcher and activation errors also send a native desktop notification. Launcher
errors are retained in `desktop.log`; activation errors are also retained in
`~/.local/state/t3code-bundle-updater/activation.log`. Notification delivery
depends on the desktop session and its notification settings.

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

Inspect retained releases with `nix-env --profile
~/.local/state/nix/profiles/t3code-staged --list-generations`. Select the desired
staged generation with `--switch-generation NUMBER`, then run `t3-activate`.
Only activation changes the running pair. Application data is not rolled back;
confirm compatibility before selecting an older release. The next automatic
check can stage the current nightly again.
