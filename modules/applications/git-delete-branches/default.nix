{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [
      (features.shell.packages { inherit pkgs; }).deleteBranches
    ];
  };
in
{
  flake.modules.nixos.git-delete-branches =
    { config, ... }:
    let
      home = config.users.users.${config.workstation.user}.home;
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [
        "r ${home}/.local/bin/git-delete-branches - - - -"
        "r ${home}/.local/bin/git-db - - - -"
      ];
    };
  flake.modules.darwin.git-delete-branches = common;
}
