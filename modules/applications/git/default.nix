{ config, ... }:
let
  inherit (config) features;
  deltaConfiguration =
    { lib, pkgs }:
    let
      theme = features.theme { inherit lib pkgs; };
    in
    pkgs.writeText "delta.gitconfig" (lib.generators.toGitINI { inherit (theme) delta; });
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.git ];
    environment.variables.GIT_CONFIG_GLOBAL = "$HOME/.config/git/config";
  };
in
{
  flake.modules.nixos.git =
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
      checkout = config.workstation.checkout;
      deltaConfig = deltaConfiguration { inherit lib pkgs; };
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [
        "d ${home}/.config/git 0700 ${user} ${group} - -"
        "L+ ${home}/.config/git/config - - - - ${checkout}/modules/applications/git/config"
        "L+ ${home}/.config/git/themes.gitconfig - - - - ${deltaConfig}"
        "L+ ${home}/.config/git/ignore - - - - ${checkout}/modules/applications/git/ignore"
      ];
    };
  flake.modules.darwin.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      checkout = config.workstation.checkout;
    in
    {
      imports = [ common ];
      workstation.links = {
        ".config/git/config" = "${checkout}/modules/applications/git/config";
        ".config/git/ignore" = "${checkout}/modules/applications/git/ignore";
        ".config/git/themes.gitconfig" = toString (deltaConfiguration {
          inherit lib pkgs;
        });
      };
    };
}
