{
  config,
  lib,
  pkgs,
  ...
}:

let
  updatePackages = pkgs.writeShellApplication {
    name = "nix-update-packages";
    runtimeInputs = [
      pkgs.nix
      pkgs.systemd
    ];
    text = ''
      checkout="''${1:-/data/code/nixos-config}"
      nix flake update --flake "path:$checkout"
      /run/current-system/sw/bin/t3-update-now
      /run/current-system/sw/bin/update-llm-agents
    '';
  };
in
{
  nix = {
    settings.trusted-users = lib.mkForce [ "root" ];
    optimise.automatic = true;
    gc.dates = "weekly";
  };

  environment.systemPackages = [ updatePackages ];
  assertions = [
    {
      assertion = config.nix.settings.trusted-users == [ "root" ];
      message = "Only root may be a trusted Nix user on Othinus.";
    }
  ];
}
