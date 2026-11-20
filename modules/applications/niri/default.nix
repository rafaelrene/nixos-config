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
      cfg = config.workstation.niri;
      theme = features.theme { inherit lib pkgs; };
      niriConfig = pkgs.writeText "niri-config.kdl" (
        lib.replaceStrings
          [ "@accent@" "@surface2@" "@urgent@" "@gdbus@" "@extraBinds@" ]
          [
            theme.accentColor
            theme.colors.surface2
            theme.colors.red
            "${pkgs.glib.bin}/bin/gdbus"
            cfg.extraBinds
          ]
          (builtins.readFile ./config.kdl + cfg.extraConfig)
      );
    in
    {
      imports = [ (features.modulesFor "nixos").wallpaper ];
      options.workstation.niri = {
        displayResolution = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Preferred display resolution, also used to select wallpaper variants.";
        };
        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Additional native Niri KDL for this machine.";
        };
        extraBinds = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Additional native Niri bindings for this machine.";
        };
      };
      config = {
        programs.niri = {
          enable = true;
          useNautilus = false;
        };
        services.displayManager.defaultSession = "niri";
        xdg.portal.config.niri."org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        systemd = {
          tmpfiles.rules = [
            "d ${home}/.config/niri 0700 ${user} ${group} - -"
            "L+ ${home}/.config/niri/config.kdl - - - - ${niriConfig}"
          ];
        };
      };
    };
}
