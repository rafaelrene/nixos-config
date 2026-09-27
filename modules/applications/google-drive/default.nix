{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.google-drive = { lib, pkgs, ... }: {
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
