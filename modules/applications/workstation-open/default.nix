{ config, ... }:
let
  inherit (config) features;
  common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = [
        (features.workstation-open.package {
          inherit pkgs;
          home = config.users.users.${config.workstation.user}.home;
          code = config.workstation.codeRoot;
          hostname = lib.toLower config.networking.hostName;
        })
      ];
    };
in
{
  flake.modules.nixos.workstation-open = common;
  flake.modules.darwin.workstation-open = common;
}
