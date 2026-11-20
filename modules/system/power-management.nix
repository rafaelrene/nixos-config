{
  flake.modules = {
    nixos.power-management =
      { lib, ... }:
      {
        options.workstation.power.dmsSettings = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.oneOf [
              lib.types.bool
              lib.types.int
              lib.types.str
            ]
          );
          description = "Power profiles and idle timers applied to DMS.";
        };

        config = {
          services = {
            power-profiles-daemon.enable = true;
            logind.settings.Login.IdleAction = lib.mkDefault "ignore";
          };

          workstation.power.dmsSettings = lib.mapAttrs (_: lib.mkDefault) {
            acMonitorTimeout = 0;
            acLockTimeout = 0;
            acSuspendTimeout = 0;
            acProfileName = "balanced";
            batteryMonitorTimeout = 900;
            batteryLockTimeout = 600;
            batterySuspendTimeout = 900;
            batteryProfileName = "power-saver";
            lockBeforeSuspend = true;
          };
        };
      };

    darwin.power-management =
      { config, lib, ... }:
      {
        power.sleep = {
          computer = "never";
          harddisk = "never";
          display = "never";
        };
        system.defaults.CustomSystemPreferences."com.apple.loginwindow".SleepDisabled = true;
        system.activationScripts = {
          power.text = lib.mkAfter ''
            /usr/bin/pmset -a sleep 0 disksleep 0 displaysleep ${
              if config.power.sleep.display == "never" then "0" else toString config.power.sleep.display
            }
          '';
          postActivation.text = lib.mkAfter ''
            restart_power_failure=$(/usr/sbin/systemsetup -getrestartpowerfailure)
            if [[ "$restart_power_failure" != *"Not supported"* ]]; then
              /usr/sbin/systemsetup -setrestartpowerfailure on
            fi
            /usr/bin/pmset -a disablesleep 1
          '';
        };
      };
  };
}
