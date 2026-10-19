{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.git ];
    environment.variables.GIT_CONFIG_GLOBAL = "$HOME/.config/git/config";
  };
in
{
  flake.modules.nixos.git =
    {
      config,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
      source =
        path:
        features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = path;
        };
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [
        "d ${home}/.config/git 0700 ${user} ${group} - -"
        "L+ ${home}/.config/git/config - - - - ${source ./config}"
        "L+ ${home}/.config/git/ignore - - - - ${source ./ignore}"
      ];
    };
  flake.modules.darwin.git =
    {
      config,
      ...
    }:
    let
      source =
        path:
        features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = path;
        };
    in
    {
      imports = [ common ];
      workstation.links = {
        ".config/git/config" = source ./config;
        ".config/git/ignore" = source ./ignore;
      };
    };
}
