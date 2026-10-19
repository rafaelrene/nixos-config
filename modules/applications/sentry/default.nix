{ config, ... }:
let
  inherit (config) features;
  common = { pkgs, ... }: {
    environment.systemPackages = [ (features.sentry.package { inherit pkgs; }) ];
    environment.variables.SENTRY_CLI_NO_UPDATE_CHECK = "1";
  };
in
{
  flake.modules.nixos.sentry = common;
  flake.modules.darwin.sentry = common;
}
