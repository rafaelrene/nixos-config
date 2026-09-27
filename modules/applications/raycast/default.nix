{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.raycast = { lib, pkgs, ... }: {
    environment.systemPackages = [ (features.raycast.package { inherit lib pkgs; }) ];
  };
}
