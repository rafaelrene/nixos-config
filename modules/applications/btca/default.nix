{ config, lib, ... }:
let
  inherit (config) features;
in
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    btca =
      { config, pkgs, ... }:
      let
        home = config.users.users.${config.workstation.user}.home;
        runtimes = features.shell.runtimes { inherit pkgs; };
        cleanup = features.shell.application {
          inherit pkgs;
          name = "btca-clean";
          runtimeInputs = [ pkgs.git ];
          text = ''
            exec ${runtimes.python3} ${./cleanup.py} ${lib.escapeShellArg "${home}/.local/share/btca-sandbox"} "$@"
          '';
        };
      in
      {
        environment.systemPackages = [ cleanup ];
      }
      // lib.optionalAttrs (platform == "nixos") {
        systemd.user = {
          services.btca-clean = {
            description = "Remove unused btca reference clones after one day";
            unitConfig.ConditionUser = config.workstation.user;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe cleanup;
            };
          };
          timers.btca-clean = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              # Drop development-shell roots before the daily Nix collector.
              OnCalendar = "*-*-* 02:50:00";
              Persistent = true;
            };
          };
        };
      }
      // lib.optionalAttrs (platform == "darwin") {
        launchd.user.agents.btca-clean = {
          command = lib.getExe cleanup;
          serviceConfig = {
            RunAtLoad = true;
            StartCalendarInterval = {
              Hour = 2;
              Minute = 50;
            };
            ProcessType = "Background";
            StandardOutPath = "${home}/Library/Logs/btca-clean.log";
            StandardErrorPath = "${home}/Library/Logs/btca-clean.log";
          };
        };
      };
  });
}
