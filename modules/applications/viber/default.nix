{ config, ... }:
let
  inherit (config) features;
in
{
  # Native updater disablement has not been verified for this application.
  flake.modules.darwin.viber = { pkgs, ... }: {
    environment.systemPackages = [
      (features.viber.package { inherit pkgs; })
    ];
  };
}
