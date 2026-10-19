{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.niri =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
      displayResolution = "2560x1440";
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
      wallpaperSource = ../../../wallpapers;
      wallpaperFiles = builtins.readDir wallpaperSource;
      # Resolution variants belong to their original, never to a separate rotation entry.
      originals = builtins.filter (
        name:
        wallpaperFiles.${name} == "regular"
        && builtins.match ".*\\.(jpg|jpeg|png|webp)" name != null
        && builtins.match ".*-[0-9]+x[0-9]+\\.[^.]+" name == null
      ) (builtins.attrNames wallpaperFiles);
      wallpapers = pkgs.linkFarm "wallpapers" (
        map (
          original:
          let
            parts = builtins.match "(.*)\\.([^.]+)" original;
            variant = "${builtins.elemAt parts 0}-${displayResolution}.${builtins.elemAt parts 1}";
            selected = if wallpaperFiles.${variant} or null == "regular" then variant else original;
          in
          {
            name = selected;
            path = wallpaperSource + "/${selected}";
          }
        ) originals
      );
      theme = features.theme { inherit lib pkgs; };
      niriConfig = pkgs.writeText "niri-config.kdl" (
        lib.replaceStrings
          [ "@accent@" "@surface2@" "@urgent@" "@displayResolution@" "@gdbus@" ]
          [
            theme.accentColor
            theme.colors.surface2
            theme.colors.red
            displayResolution
            "${pkgs.glib.bin}/bin/gdbus"
          ]
          (builtins.readFile ./config.kdl)
      );
    in
    {
      programs.niri = {
        enable = true;
        useNautilus = false;
      };
      services.displayManager.defaultSession = "niri";
      xdg.portal.config.niri."org.freedesktop.impl.portal.Settings" = [ "gtk" ];
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
        tmpfiles.rules = [
          "d ${home}/Pictures 0755 ${user} ${group} - -"
          "L+ ${home}/Pictures/Wallpapers - - - - ${wallpapers}"
          "d ${home}/.config/niri 0700 ${user} ${group} - -"
          "L+ ${home}/.config/niri/config.kdl - - - - ${niriConfig}"
        ];
      };
    };
}
