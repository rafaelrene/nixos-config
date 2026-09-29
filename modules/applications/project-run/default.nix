{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [ (features.shell.packages { inherit pkgs; }).project-run ];
  };
in
{
  flake.modules.nixos.project-run = common;
  flake.modules.darwin.project-run = common;
}
