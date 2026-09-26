{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../../../themes { inherit lib pkgs; };
  colors = lib.mapAttrs (_: color: "#${color}") theme.colors;
  palette = (pkgs.formats.toml { }).generate "workstation.toml" {
    meta = {
      version = 1;
      inherit (theme) name;
      variant = if theme.dark then "dark" else "light";
    };
    colors = {
      core = {
        background = colors.base;
        foreground = colors.text;
        secondary_background = colors.mantle;
        border = colors.surface1;
        accent = "#${theme.accentColor}";
        accent_foreground = colors.crust;
      };
      accents = {
        inherit (colors)
          blue
          green
          red
          yellow
          ;
        magenta = colors.pink;
        orange = colors.peach;
        purple = colors.mauve;
        cyan = colors.teal;
      };
      list.item.selection = {
        background = colors.surface0;
        secondary_background = colors.surface1;
      };
      grid.item.background = colors.surface0;
    };
  };
  vicinaeOverrides = pkgs.writeText "vicinae-overrides.json" (
    builtins.toJSON {
      providers.applications.preferences.defaultAction = "launch";
      font.normal.family = theme.font.interface;
      theme = {
        light = {
          name = "workstation";
          icon_theme = theme.icons.name;
        };
        dark = {
          name = "workstation";
          icon_theme = theme.icons.name;
        };
      };
    }
  );
in
{
  environment.systemPackages = [ pkgs.vicinae ];
  systemd.user.services.vicinae = {
    description = "Vicinae launcher";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [
      config.system.path
      pkgs.pulseaudio
    ];
    # Apply launch defaults and styling without replacing writable user settings.
    environment.VICINAE_OVERRIDES = toString vicinaeOverrides;
    unitConfig.ConditionUser = "raf";
    serviceConfig = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server --replace";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/raf/.local/share/vicinae/themes 0700 raf raf - -"
    "L+ /home/raf/.local/share/vicinae/themes/workstation.toml - - - - ${palette}"
    "d /home/raf/.config/vicinae 0700 raf raf - -"
    "C /home/raf/.config/vicinae/config.json 0600 raf raf - ${./config.json}"
  ];
}
