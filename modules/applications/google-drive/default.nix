{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.google-drive =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      user = config.workstation.user;
      inherit (config.users.users.${user}) home group;
      configuration = "${home}/.config/google-drive/rclone.conf";
      mountPoint = "${home}/GoogleDrive";
    in
    {
      environment.systemPackages = [ pkgs.rclone ];
      programs.fuse.enable = true;
      systemd.tmpfiles.rules = [ "d ${mountPoint} 0700 ${user} ${group} - -" ];
      systemd.user.services.google-drive = {
        description = "Mount Google Drive";
        wantedBy = [ "default.target" ];
        unitConfig = {
          ConditionUser = user;
          ConditionPathExists = configuration;
        };
        environment.PATH = lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin";
        serviceConfig = {
          ExecStart = utils.escapeSystemdExecArgs [
            (lib.getExe pkgs.rclone)
            "--config"
            configuration
            "mount"
            "google-drive:"
            mountPoint
            "--vfs-cache-mode"
            "writes"
          ];
          Restart = "on-failure";
          RestartSec = 30;
          UMask = "0077";
        };
      };
    };

  flake.modules.darwin.google-drive =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ (features.modulesFor "darwin").desktop-session ];
      workstation.desktop.backgroundApplications = [ "Google Drive" ];
      environment.systemPackages = [
        (features.google-drive.package { inherit pkgs; })
      ];
      system.activationScripts = {
        # Reject unmanaged vendor paths before activation changes applications.
        preActivation.text = lib.mkBefore ''
          destination="/Applications/Google Drive.app"
          target="/Applications/Nix Apps/Google Drive.app"
          if test -L "$destination" && test "$(readlink "$destination")" = "$target"; then
            :
          elif test -e "$destination" || test -L "$destination"; then
            echo "Refusing to replace unmanaged application: $destination" >&2
            exit 1
          fi
        '';
        defaults.text = lib.mkIf ((config.workstation.desktop.sessionPolicy or null) == "unattended") (
          lib.mkAfter ''
            # Override the in-app login setting before the Nix agent starts Drive.
            /usr/bin/dscl . -mcxset ${lib.escapeShellArg "/Users/${config.system.primaryUser}"} \
              com.google.drivefs.settings AutoStartOnLogin always -bool false
            /usr/bin/mcxrefresh -n ${lib.escapeShellArg config.system.primaryUser}
          ''
        );
        postActivation.text = lib.mkAfter ''
          # Upstream helpers use this fixed path. Keep just one actual app bundle.
          destination="/Applications/Google Drive.app"
          target="/Applications/Nix Apps/Google Drive.app"
          if test -L "$destination" && test "$(readlink "$destination")" = "$target"; then
            :
          elif test -e "$destination" || test -L "$destination"; then
            echo "Refusing to replace unmanaged application: $destination" >&2
            exit 1
          else
            ln -s "$target" "$destination"
          fi
          # Match the vendor installer's mount-helper permissions, outside the store.
          chown root:wheel '/Applications/Nix Apps/Google Drive.app/Contents/MacOS/mount_helper'
          chmod 4755 '/Applications/Nix Apps/Google Drive.app/Contents/MacOS/mount_helper'
          # Merge only Drive's update policy; retain policies for other Google apps.
          (
            set -eu
            policy=$(mktemp)
            trap 'rm -f "$policy" "$policy.json"' EXIT
            domain=/Library/Preferences/com.google.Keystone
            if test -f "$domain.plist"; then
              /usr/bin/defaults export "$domain" - | /usr/bin/plutil -convert json -o "$policy.json" -
            else
              echo '{}' > "$policy.json"
            fi
            ${lib.getExe pkgs.jq} '.updatePolicies["com.google.drivefs"].UpdateDefault = 3' "$policy.json" > "$policy"
            /usr/bin/plutil -convert xml1 "$policy"
            /usr/bin/defaults import "$domain" "$policy"
          )
        '';
      };
    };
}
