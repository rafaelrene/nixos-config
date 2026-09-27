{ config, ... }:
let
  inherit (config) features;
  configuration =
    { lib, pkgs, ... }:
    let
      theme = features.theme { inherit lib pkgs; };
      settings = builtins.fromTOML (builtins.readFile ./starship.toml);
      starshipConfig = (pkgs.formats.toml { }).generate "starship.toml" (
        settings
        // {
          palette = "workstation";
          palettes.workstation = builtins.mapAttrs (_: color: "#${color}") theme.colors;
        }
      );
    in
    starshipConfig;
  common = { pkgs, ... }: { environment.systemPackages = [ pkgs.starship ]; };
in
{
  flake.modules.nixos.starship =
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
      starshipConfig = configuration { inherit lib pkgs; };
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [
        "d ${home}/.config/starship 0700 ${user} ${group} - -"
        "L+ ${home}/.config/starship/starship.toml - - - - ${starshipConfig}"
      ];
    };
  flake.modules.darwin.starship =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      home = config.users.users.${config.workstation.user}.home;
    in
    {
      imports = [ common ];
      environment.variables.STARSHIP_CONFIG = "${home}/.config/starship/starship.toml";
      workstation.links.".config/starship/starship.toml" = toString (configuration {
        inherit lib pkgs;
      });
    };
}
