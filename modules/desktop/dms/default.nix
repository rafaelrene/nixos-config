{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  tokens = {
    inherit (theme) name;
    accent = "#${theme.accentColor}";
  }
  // lib.mapAttrs (_: color: "#${color}") theme.colors;
  dmsTheme = pkgs.writeText "dms-theme.json" (
    lib.replaceStrings (map (name: "@${name}@") (
      builtins.attrNames tokens
    )) (builtins.attrValues tokens) (builtins.readFile ./theme.json)
  );
  defaults = builtins.fromJSON (builtins.readFile ./default-settings.json);
  dmsSettings = pkgs.writeText "dms-default-settings.json" (
    builtins.toJSON (
      defaults
      // {
        fontFamily = theme.font.interface;
        monoFontFamily = theme.font.monospace;
      }
    )
  );
in
{
  programs.dms-shell.enable = true;
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/DankMaterialShell 0700 raf raf - -"
    "L+ /home/raf/.config/DankMaterialShell/theme.json - - - - ${dmsTheme}"
    "C /home/raf/.config/DankMaterialShell/settings.json 0600 raf raf - ${dmsSettings}"
  ];
}
