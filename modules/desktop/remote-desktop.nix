{
  flake.modules.darwin.remote-desktop =
    # macOS still requires screen-control approval or an MDM EnableRemoteDesktop command.
    { config, lib, ... }:
    {
      system.activationScripts.launchd.text = lib.mkMerge [
        (lib.mkOrder 400 ''
          (
          remote_desktop_native_loaded=false
          remote_desktop_managed_loaded=false
          remote_desktop_handoff_complete=false
          if /bin/launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
            remote_desktop_native_loaded=true
          fi
          if /bin/launchctl print system/org.nixos.remote-desktop >/dev/null 2>&1; then
            remote_desktop_managed_loaded=true
          fi
          # shellcheck disable=SC2329 # Invoked by the EXIT trap.
          restore_remote_desktop() {
            "$remote_desktop_handoff_complete" && return 0
            /bin/launchctl bootout system/org.nixos.remote-desktop >/dev/null 2>&1 || true
            /bin/launchctl disable system/org.nixos.remote-desktop || true
            if "$remote_desktop_native_loaded"; then
              /bin/launchctl enable system/com.apple.screensharing || true
              /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist ||
                printf >&2 'Could not restore the previous Screen Sharing service.\n'
            elif "$remote_desktop_managed_loaded"; then
              /bin/cp -f /run/current-system/Library/LaunchDaemons/org.nixos.remote-desktop.plist \
                /Library/LaunchDaemons/org.nixos.remote-desktop.plist &&
                /bin/launchctl enable system/org.nixos.remote-desktop &&
                /bin/launchctl bootstrap system /Library/LaunchDaemons/org.nixos.remote-desktop.plist ||
                printf >&2 'Could not restore the previous remote desktop service.\n'
            fi
          }
          trap restore_remote_desktop EXIT
          kickstart=/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart
          "$kickstart" -configure -allowAccessFor -specifiedUsers
          "$kickstart" -configure -access -on -privs -ControlObserve -users ${lib.escapeShellArg config.system.primaryUser}
          /usr/bin/install -d -m 0755 '/Library/Application Support/Apple/Remote Desktop'
          printf enabled > '/Library/Application Support/Apple/Remote Desktop/RemoteManagement.launchd'
          /bin/launchctl bootout system/com.apple.screensharing >/dev/null 2>&1 || true
          /bin/launchctl disable system/com.apple.screensharing
          /bin/launchctl enable system/org.nixos.remote-desktop
        '')
        (lib.mkOrder 1700 ''
          if ! /bin/launchctl print system/org.nixos.remote-desktop >/dev/null 2>&1; then
            /bin/launchctl bootstrap system /Library/LaunchDaemons/org.nixos.remote-desktop.plist
          fi
          /bin/launchctl print system/org.nixos.remote-desktop >/dev/null
          remote_desktop_handoff_complete=true
          trap - EXIT
          )
        '')
      ];
      environment.launchDaemons."org.nixos.remote-desktop.plist".text =
        lib.generators.toPlist { escape = true; }
          {
            Label = "org.nixos.remote-desktop";
            ProgramArguments = [
              "/System/Library/CoreServices/RemoteManagement/screensharingd.bundle/Contents/MacOS/screensharingd"
            ];
            Disabled = false;
            ProcessType = "Interactive";
            EnableTransactions = true;
            SHAuthorizationRight = "system.preferences";
            MachServices."com.apple.screensharing.server" = {
              HideUntilCheckIn = true;
              ResetAtClose = true;
            };
            Sockets.Listener = [
              {
                SockNodeName = "127.0.0.1";
                SockServiceName = "5901";
                SockFamily = "IPv4";
              }
              {
                SockNodeName = "::1";
                SockServiceName = "5901";
                SockFamily = "IPv6";
              }
            ];
          };
    };
}
