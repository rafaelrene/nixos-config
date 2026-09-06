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

- Support cloning and rebuilding from any checkout directory. Replace the
  hardcoded `/data/code/nixos-config` paths as part of that work; retain them
  until then.
- Unify all package updates behind one explicit command. Move T3Code and the
  agent tools into the system configuration, record their versions in this
  repository, and remove their separate profiles and automatic update timers.
  The command should refresh flake dependencies and T3Code's version and hashes,
  then rebuild and switch the system. Packages should update only when this
  command is run. Obtain explicit approval for the helper before implementing it.
- Add Tailscale for T3Code access outside the trusted LAN.
- Consider lowering the internal display to 60 Hz on battery.
- Revisit dedicated coding workspace rules after the Niri workflow settles.
- Revisit the global Catppuccin accent. It is currently Mocha Mauve.
- Revisit Helium as the default browser if work and personal usage changes.
- Remove `nh` if it does not improve the update workflow.
- Add optional forwarding of Othinus agent notifications to the Mac; keep notifications local to Othinus for now.
- Install and authenticate the Bitbucket CLI expected by the resolve-pr-comments skill (bkt); until then, the skill reports the missing prerequisite for Bitbucket work.
- Fix `nvim` showing bunch of errors on launch
- T3Code is not showing usage statistics
- T3 Server that's running can not be configured. I can't connect to t3connect or use any connection settings
