{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules = {
    generic.nix = {
      nixpkgs.config.allowUnfree = true;
      nix = {
        settings = {
          min-free = 10 * 1024 * 1024 * 1024;
          max-free = 20 * 1024 * 1024 * 1024;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = [
            "https://cache.nixos.org"
            "https://devenv.cachix.org"
            "https://cache.numtide.com"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbZGZpVJ8lrQ1kX7H7lYZ7cP0E="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          ];
        };
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
      };
    };
    nixos.nix =
      let
        shared = (config.features.modulesFor "generic").nix;
      in
      {
        config,
        lib,
        ...
      }:

      {
        imports = [ shared ];
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
            message = "Only root may be a trusted Nix user.";
          }
        ];
      };

    darwin.nix =
      let
        shared = (config.features.modulesFor "generic").nix;
      in
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
        imports = [ shared ];
        nix.settings.trusted-users = [ "root" ];
        nix.gc.interval = {
          Hour = 3;
          Minute = 0;
        };
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
  };
}
