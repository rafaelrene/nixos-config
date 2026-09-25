# Raycast investigation handover

Status: root cause fixed and runtime verified, 2026-09-25. System activation
remains pending. Investigation continued locally on Proserpina in
`/Users/rafael/code/.personal/nixos-config` after the Othinus-hosted thread.

## Resolution

The pre-migration launch log at 13:38 records version **2.5.2.0**. Nix installed
**2.4.1.0**, which cannot open the newer database schemas. Repeated launches
failed migrations for `ai`, `app_index` and `settings_v2`; the backend exited
after failing to initialize root search, producing the restart alert.

`modules/darwin/packages.nix` now uses the upstream signed 2.5.2 archive and
checksum when the unstable package is older. Once Nixpkgs catches up, its package
takes precedence. No database, settings, hotkey or permission reset was needed.

Validation:

- The archive hash matches both the current upstream Nixpkgs package and cask.
- The built app passes deep, strict codesign verification.
- Launching the built 2.5.2 app against existing state initializes all 11
  databases with no failed migrations; the frontend completes startup.
- Rene confirmed “It's working now.” The saved hotkey remains Command-Space.
- Raycast registered a login item for the running Nix-store bundle. Recheck its
  path after launching the installed copy; an actual login has not been tested.
- Nix evaluation, the full Darwin build, formatting and lint passed. No new VM
  activation was performed; the prior testing environment was retired.
- Othinus's system derivation is unchanged, and its build passed on Othinus.

The working app is currently launched from
`/nix/store/kj559zwiyl9xmzik4ps0qbkfrvzpaicp-raycast-2.5.2.0/Applications/Raycast.app`.
The installed `/Applications/Nix Apps/Raycast.app` remains 2.4.1 until an
authorized system switch. Quit Raycast before switching, then launch its
installed copy and verify the hotkey and login-item path again.

Existing app-support directories and preferences were backed up locally under
`~/.local/state/nix-darwin/backups/raycast-2026-09-25` before the successful launch.
These contain private state and must stay outside the repository and Nix store.

The observations below describe the original failure, before the fix.

## Symptom

After the nix-darwin migration, Raycast's global keyboard shortcut does nothing.
Opening the app also failed to show the normal search window. Rene subsequently
saw an alert and clarified its exact wording: **“Raycast failed to restart.”**
The alert text and its cause have not yet been investigated locally.

## Confirmed observations

- Nix app: `/Applications/Nix Apps/Raycast.app`, bundle ID `com.raycast.macos`,
  version `2.4.1.0`. Its deep, strict codesign verification passed.
- The Brew app `/Applications/Raycast.app` was removed by the authorized cleanup.
  Its cask receipt previously reported version `1.104.25`; the old running bundle
  might have self-updated, so that receipt is not a verified prior runtime version.
- `defaults read com.raycast.macos raycastGlobalHotkey` returned `Command-49`
  (Command-Space). Spotlight shortcuts 64 and 65 were both disabled.
- A read-only query of the system TCC database returned
  `kTCCServiceAccessibility|2` for `com.raycast.macos`. This establishes that a
  grant exists, not that every permission/path check succeeds at runtime.
- A normal AppleScript quit returned `User cancelled. (-128)`. The original main
  process later exited; no force-kill was performed.
- `open -n -W '/Applications/Nix Apps/Raycast.app'` launched a fresh main process.
  Its sampled main thread was in `-[NSAlert runModal]`, waiting in the AppKit
  event loop. This proves a modal alert was active, not its cause.
- Activating the app with NSRunningApplication brought the alert forward.
  Rene then supplied the exact message above. There is no confirmed fix.
- An old `RaycastAppIntents` extension process still referenced the removed
  `/Applications/Raycast.app` and predated migration. It was not terminated.
  The new bundle did not contain that extension at the inspected old relative
  path. Do not assume this stale process causes the failure without testing.
- No Raycast crash reports were found in the user's DiagnosticReports directory.
  Launch logs contained WebKit Memorystatus “Invalid argument (22)” messages;
  their relevance is unproven.

No Raycast settings, databases, hotkeys, permissions or updater preferences
were changed during this investigation. Temporary process samples were deleted.
Re-check current processes instead of reusing old PIDs.

## Next investigation

1. Inspect the alert and reproduce the failed restart locally. Capture only
   Raycast-specific diagnostics; avoid unrelated desktop or credential output.
2. Distinguish a self-updater/relaunch failure from a permission or installation
   path problem before changing configuration. Preserve Raycast's existing data.
3. Verify both opening Raycast and Command-Space after any fix. Confirm login
   startup too, since Brew cleanup removed Raycast's old login item.

The manual documents [troubleshooting](https://manual.raycast.com/troubleshooting)
and [keyboard shortcuts](https://manual.raycast.com/keyboard-shortcuts).

## Migration context

The final system activation succeeded. Active generation at handover:
`/nix/store/gdz6lfkgg9lkn45wlxnihw397m4xphly-darwin-system-26.05.c3e90c8`.
`workstation.removeReplacedHomebrewPackages = true` remains enabled. Declared
Brew replacements were removed; unrelated packages remain. Do not redo the
initial migration or restore old configurations to diagnose this app.

Rene verified Google Drive, Proton Drive, Tailscale and RustDesk. Their Nix paths,
vendor integration and File Provider registrations were checked over SSH. Managed
T3Code responds on `127.0.0.1:3773`, and Nix agent commands work. A running server
does not by itself prove this new thread is executing on the Mac: confirm its
workspace and hostname before investigating.

Private migration backups and detailed recovery notes remain on Othinus under
`/data/backups/proserpina/2026-09-25`. Do not copy credentials into this public
repository. Avoid dumping launchd environments: they contain existing secrets.

Both Tart VMs, downloaded images and Tart were deleted at Rene's request after
testing. Native checks were explicitly accepted for the small Tailscale wrapper
fix. Consult AGENTS.md before new configuration or activation changes. No new
system switch is needed merely to start this investigation.
