{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [ (features.bkt.package { inherit pkgs; }) ];
  };
in
{
  flake.modules.nixos.bkt = common;
  flake.modules.darwin.bkt = common;
}
