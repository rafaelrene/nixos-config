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
{
  environment.systemPackages = [ pkgs.starship ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/starship 0700 raf raf - -"
    "L+ /home/raf/.config/starship/starship.toml - - - - ${starshipConfig}"
  ];
}
