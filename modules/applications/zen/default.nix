{ config, ... }:
let
  inherit (config) features;
  updatePolicies.DisableAppUpdate = true;
  common = { lib, pkgs, ... }: {
    environment.systemPackages = [
      (features.zen.package {
        inherit lib pkgs;
        policies = updatePolicies;
      })
    ];
  };
in
{
  flake.modules = {
    nixos.zen = common;
    darwin.zen = {
      imports = [ common ];
      system.defaults.CustomUserPreferences."app.zen-browser.zen" = updatePolicies // {
        EnterprisePoliciesEnabled = true;
      };
    };
  };
}
