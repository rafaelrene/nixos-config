{ config, ... }:
let
  modules = config.features.modulesFor "nixos";
in
{
  flake.modules.nixos.othinus.imports = [ modules.othinus-display ];
  flake.modules.nixos.othinus-display =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      displayResolution = config.workstation.niri.displayResolution;
      batteryRefreshRate = pkgs.writeShellApplication {
        name = "niri-battery-refresh-rate";
        runtimeInputs = [
          config.programs.niri.package
          pkgs.coreutils
          pkgs.zsh
          pkgs.jq
          pkgs.systemd
          pkgs.upower
        ];
        text = ''
          exec ${lib.getExe pkgs.zsh} -f ${./battery-refresh-rate.zsh} "$@"
        '';
      };
    in
    {
      imports = [
        modules.niri
        modules.brightnessctl
      ];
      workstation.niri = {
        displayResolution = "2560x1440";
        extraConfig = ''
          output "eDP-1" {
              // The refresh service selects 165 Hz with VRR on AC and 60 Hz on battery.
              mode "${displayResolution}"
              scale 1.5
          }
        '';
        extraBinds = ''
          XF86MonBrightnessUp allow-when-locked=true repeat=false { spawn-sh "systemctl --user stop display-dimming.service && brightnessctl --class=backlight set 100% && niri msg action power-on-monitors"; }
          XF86MonBrightnessDown allow-when-locked=true repeat=false { spawn-sh "systemctl --user start display-dimming.service && niri msg action power-off-monitors"; }
        '';
      };
      systemd = {
        user = {
          services = {
            niri-battery-refresh-rate = {
              description = "Adjust the internal display refresh rate to AC power";
              wantedBy = [ "graphical-session.target" ];
              partOf = [ "graphical-session.target" ];
              after = [ "graphical-session.target" ];
              unitConfig.ConditionUser = user;
              serviceConfig = {
                ExecStart = "${lib.getExe batteryRefreshRate} ${displayResolution}";
                Restart = "always";
                RestartSec = 2;
              };
            };
            display-dimming = {
              description = "Blacken physical displays while preserving desktop capture";
              partOf = [ "graphical-session.target" ];
              after = [ "graphical-session.target" ];
              unitConfig.ConditionUser = user;
              serviceConfig = {
                # The panel's minimum backlight is still lit. A zero color ramp
                # makes scanout black without changing rendering or screenshots.
                ExecStartPre = "${pkgs.brightnessctl}/bin/brightnessctl --class=backlight --min-value=0 set 0";
                ExecStart = "${lib.getExe pkgs.wl-gammactl} -b 0";
                Restart = "on-failure";
                RestartSec = 2;
              };
            };
            display-brightness-schedule = {
              description = "Apply the daytime or nighttime display brightness";
              wantedBy = [ "graphical-session.target" ];
              partOf = [ "graphical-session.target" ];
              after = [ "graphical-session.target" ];
              unitConfig.ConditionUser = user;
              serviceConfig.Type = "oneshot";
              # Check local time so login and missed runs apply the current schedule.
              script = ''
                case "$(${pkgs.coreutils}/bin/date +%H)" in
                  23|0[0-9])
                    ${pkgs.systemd}/bin/systemctl --user start display-dimming.service
                    ${lib.getExe config.programs.niri.package} msg action power-off-monitors
                    ;;
                  *)
                    ${pkgs.systemd}/bin/systemctl --user stop display-dimming.service
                    ${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set 100%
                    ${lib.getExe config.programs.niri.package} msg action power-on-monitors
                    ;;
                esac
              '';
            };
          };
          timers.display-brightness-schedule = {
            wantedBy = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            unitConfig.ConditionUser = user;
            timerConfig = {
              OnCalendar = "*-*-* 10,23:00:00";
              AccuracySec = "1s";
              Persistent = true;
            };
          };
        };
      };
    };
}
