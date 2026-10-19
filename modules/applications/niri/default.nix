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
            variant = "${builtins.elemAt parts 0}-${toString cfg.displayResolution}.${builtins.elemAt parts 1}";
            selected =
              if cfg.displayResolution != null && wallpaperFiles.${variant} or null == "regular" then
                variant
              else
                original;
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
      options.workstation.niri = {
        displayResolution = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Resolution used to select wallpaper variants, or null for originals.";
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
            "d ${home}/Pictures 0755 ${user} ${group} - -"
            "L+ ${home}/Pictures/Wallpapers - - - - ${wallpapers}"
            "d ${home}/.config/niri 0700 ${user} ${group} - -"
            "L+ ${home}/.config/niri/config.kdl - - - - ${niriConfig}"
          ];
        };
      };
    };
}
