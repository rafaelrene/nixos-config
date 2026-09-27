{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [ (features.shell.packages { inherit pkgs; }).prun ];
  };
in
{
  flake.modules.nixos.prun = common;
  flake.modules.darwin.prun = common;
}
