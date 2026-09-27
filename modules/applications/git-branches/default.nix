{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [
      (features.shell.packages { inherit pkgs; }).branches
    ];
  };
in
{
  flake.modules.nixos.git-branches =
    { config, ... }:
    let
      home = config.users.users.${config.workstation.user}.home;
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [ "r ${home}/.local/bin/git-branches - - - -" ];
    };
  flake.modules.darwin.git-branches = common;
}
