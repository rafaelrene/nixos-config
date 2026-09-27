{ config, ... }:
let
  inherit (config) features;
  common = { lib, pkgs, ... }: {
    environment.systemPackages = [ (features.zen.package { inherit lib pkgs; }) ];
  };
in
{
  flake.modules = {
    nixos.zen = common;
    darwin.zen = common;
  };
}
