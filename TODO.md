# TODO

## Replace DankMaterialShell with our own Quickshell

Keep DMS until the custom shell covers every feature we want. Replace features
incrementally, then remove DMS in one deliberate change.

- Bar layout and per-monitor behavior
- Dynamic Niri workspace indicator and controls
- Clock, Slovak-style numeric dates, English month and weekday names
- Calendar and event integration
- System tray and status notifier items
- Wi-Fi status, network selection, and VPN controls
- Bluetooth status and device controls
- Output volume, microphone, mixer, and device selection
- Display brightness
- Battery state, charging state, and power profiles
- Notification daemon, popups, history, and notification center
- Clipboard history
- Vicinae launcher handoff and launcher state
- Lock screen and authentication flow
- Logout, suspend, reboot, and shutdown menu
- Audio, brightness, media, and power on-screen displays
- Idle timers, locking, display power, and suspend policy UI
- CPU, memory, disk, network, temperature, and process monitoring
- Media controls and player metadata
- Weather widgets
- Wallpaper and theme integration
- Central settings UI
- Screen recording and screen sharing indicators
- Keyboard layout and input state
- DND, night light, and other quick toggles

## Later

- Migrate `zentty-project` and `zentty-subrepo` (alias `zsr`) from
  `/data/code/ansible/roles/scripts/files/` once we have a replacement for their
  Zentty pane/worklane integration. They require Zentty and are not installed here.
- Consider lowering the internal display to 60 Hz on battery.
- Revisit dedicated coding workspace rules after the Niri workflow settles.
- Revisit the global Catppuccin accent. It is currently Mocha Mauve.
- Revisit Helium as the default browser if work and personal usage changes.
- Add optional forwarding of Othinus agent notifications to the Mac; keep notifications local to Othinus for now.
- Install and authenticate the Bitbucket CLI expected by the resolve-pr-comments skill (bkt); until then, the skill reports the missing prerequisite for Bitbucket work.

## Done

- [x] Remove `nh`; use `ns`, `nup`, and `nups` for rebuilds and updates.
- [x] Settle the rebuild and update workflow with `ns`, `nup`, and `nups`;
  retain the canonical `/data/code/nixos-config` checkout path.
- [x] Fix Neovim startup errors.
- [x] Fix T3 server configuration and T3 Connect access.
