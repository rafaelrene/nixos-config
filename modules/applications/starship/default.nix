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
  common = { lib, pkgs, ... }: {
    environment.systemPackages = [ pkgs.starship ];
    environment.variables.STARSHIP_CONFIG = "$HOME/.config/starship/starship.toml";
    programs.zsh.promptInit = ''
      eval "$(${lib.getExe pkgs.starship} init zsh)"
    '';
  };
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
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ common ];
      workstation.links.".config/starship/starship.toml" = toString (configuration {
        inherit lib pkgs;
      });
    };
}
