{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  starshipConfig = (pkgs.formats.toml { }).generate "starship.toml" (
    settings
    // {
      palette = "workstation";
      palettes.workstation = builtins.mapAttrs (_: color: "#${color}") theme.colors;
    }
  );
in
starshipConfig
