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
      environment.systemPackages = [ (features.raycast.package { inherit pkgs; }) ];

      # Raycast can register its disabled updater services again. Stop existing
      # processes before copying the package whose updater binaries cannot run.
      system.activationScripts.applications.text = lib.mkMerge [
        (lib.mkOrder 400 ''
          (
            raycast_app='/Applications/Nix Apps/Raycast.app'
            raycast_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
            raycast_was_running=false
            raycast_finish() {
              if [[ -d "$raycast_app" && ! -L "$raycast_app" ]]; then
                # nix-darwin preserves existing owners. Prevent Raycast from
                # restoring execute permission on its packaged updater binaries.
                /usr/sbin/chown -R -P root:wheel "$raycast_app"
              fi
              if "$raycast_was_running"; then
                /bin/launchctl asuser "$raycast_uid" /usr/bin/sudo -H \
                  -u ${lib.escapeShellArg config.system.primaryUser} -- \
                  /usr/bin/open -g "$raycast_app"
              fi
            }
            # Restore ownership and the running app even if copying fails.
            trap raycast_finish EXIT

            # Keep Raycast from starting another installer during the copy.
            if /usr/bin/pgrep -x Raycast >/dev/null; then
              raycast_was_running=true
              /usr/bin/pkill -TERM -x Raycast
              for ((raycast_wait = 0; raycast_wait < 30; raycast_wait++)); do
                if ! /usr/bin/pgrep -x Raycast >/dev/null; then
                  break
                fi
                /bin/sleep 1
              done
              if /usr/bin/pgrep -x Raycast >/dev/null; then
                echo 'Raycast did not quit; refusing to replace its application.' >&2
                exit 1
              fi
            fi

            # User and GUI domains share disabled state, including when logged out.
            /bin/launchctl disable "user/$raycast_uid/com.raycast.macos.updater"
            /bin/launchctl disable system/com.raycast.macos.updater.daemon
            for raycast_service in \
              "gui/$raycast_uid/com.raycast.macos.updater" \
              system/com.raycast.macos.updater.daemon; do
              if /bin/launchctl print "$raycast_service" >/dev/null 2>&1; then
                /bin/launchctl bootout "$raycast_service"
              fi
            done
        '')
        # Enclose nix-darwin's copy and the subsequent signature verification.
        (lib.mkOrder 1700 ''
            raycast_finish
            trap - EXIT
          )
        '')
      ];
    };
}
