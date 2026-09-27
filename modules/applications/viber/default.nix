{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.viber = { pkgs, ... }: {
    environment.systemPackages = [
      (features.viber.package { inherit pkgs; })
    ];
  };
}
