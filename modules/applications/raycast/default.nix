{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.raycast =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = [ (features.raycast.package { inherit lib pkgs; }) ];

      # Stop app-owned installers before replacing applications, preserving their signatures.
      system.activationScripts.preActivation.text = lib.mkAfter ''
        (
          raycast_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
          # User and GUI domains share disabled state; the user domain also works when logged out.
          /bin/launchctl disable "user/$raycast_uid/com.raycast.macos.updater"
          /bin/launchctl disable system/com.raycast.macos.updater.daemon
          for raycast_service in \
            "gui/$raycast_uid/com.raycast.macos.updater" \
            system/com.raycast.macos.updater.daemon; do
            if /bin/launchctl print "$raycast_service" >/dev/null 2>&1; then
              /bin/launchctl bootout "$raycast_service"
            fi
          done
        )
      '';
    };
}
