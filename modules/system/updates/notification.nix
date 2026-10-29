{ config, lib, ... }:
{
  options.features.updates.notify = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Send update success and error notifications on Darwin and Linux.";
  };
  config.features.updates.notify =
    { pkgs }:
    let
      darwin = pkgs.stdenv.hostPlatform.isDarwin;
    in
    config.features.shell.application {
      inherit pkgs;
      name = "notify-update";
      runtimeInputs = lib.optionals (!darwin) [ pkgs.coreutils ];
      text =
        if darwin then
          ''
            exec /usr/bin/osascript ${./notify.applescript} "$@"
          ''
        else
          ''
            export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
            urgency=normal
            if [[ "$2" == error ]]; then urgency=critical; fi
            exec ${pkgs.libnotify}/bin/notify-send --urgency="$urgency" "$1" "$3"
          '';
    };
}
