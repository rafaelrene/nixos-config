{ config, ... }:
let
  configuration =
    { lib, pkgs }:
    let
      theme = config.features.theme { inherit lib pkgs; };
    in
    pkgs.writeText "delta.gitconfig" (
      lib.generators.toGitINI {
        inherit (theme) delta;
        core = {
          pager = "delta";
          editor = "nvim";
        };
        interactive.diffFilter = "delta --color-only";
      }
    );
in
{
  flake.modules.nixos.version-control =
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
      systemd.tmpfiles.rules = [
        "L+ ${home}/.config/git/themes.gitconfig - - - - ${configuration { inherit lib pkgs; }}"
      ];
    };

  flake.modules.darwin.version-control = { lib, pkgs, ... }: {
    workstation.links.".config/git/themes.gitconfig" = toString (configuration {
      inherit lib pkgs;
    });
  };
}
