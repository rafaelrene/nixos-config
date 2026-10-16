{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.nix =
    {
      config,
      lib,
      ...
    }:

    {
      nix = {
        settings.trusted-users = lib.mkForce [ "root" ];
        optimise.automatic = true;
        gc.dates = "daily";
      };

      # Root's collector does not prune the user's XDG profile history.
      systemd.user = lib.mkIf config.nix.gc.automatic {
        services.nix-user-gc = {
          description = "Prune old Nix user profile generations and collect unused packages";
          unitConfig.ConditionUser = config.workstation.user;
          environment.XDG_STATE_HOME = "${config.users.users.${config.workstation.user}.home}/.local/state";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${config.nix.package}/bin/nix-collect-garbage ${config.nix.gc.options}";
          };
        };
        timers.nix-user-gc = {
          description = "Clean up Nix user profiles daily";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = config.nix.gc.dates;
            Persistent = true;
          };
        };
      };

      assertions = [
        {
          assertion = config.nix.settings.trusted-users == [ "root" ];
          message = "Only root may be a trusted Nix user on Othinus.";
        }
      ];
    };

  flake.modules.darwin.system =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      home = config.users.users.${config.workstation.user}.home;
      runtimes = features.shell.runtimes { inherit pkgs; };
    in
    {
      launchd = lib.mkIf config.nix.gc.automatic {
        # Also collect after boot/login when the daily interval was missed.
        daemons.nix-gc.serviceConfig.RunAtLoad = lib.mkForce true;
        user.agents.nix-user-gc = {
          environment = {
            HOME = home;
            XDG_STATE_HOME = "${home}/.local/state";
          };
          command = "${runtimes.directory}/nix-collect-garbage ${config.nix.gc.options}";
          serviceConfig = {
            RunAtLoad = true;
            StartCalendarInterval = config.nix.gc.interval;
            ProcessType = "Background";
            StandardOutPath = "${home}/.local/state/nix-darwin/nix-user-gc.log";
            StandardErrorPath = "${home}/.local/state/nix-darwin/nix-user-gc.log";
          };
        };
      };
    };
}
