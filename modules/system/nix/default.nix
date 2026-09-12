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
      nix flake update --flake path:/data/code/nixos-config
      systemctl --user start t3code-update.service
      systemctl --user restart t3code.service
    '';
  };
in
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = lib.mkForce [ "root" ];
      substituters = [
        "https://cache.nixos.org"
        "https://devenv.cachix.org"
        "https://cache.numtide.com"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbZGZpVJ8lrQ1kX7H7lYZ7cP0E="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [ updatePackages ];
  assertions = [
    {
      assertion = config.nix.settings.trusted-users == [ "root" ];
      message = "Only root may be a trusted Nix user on Othinus.";
    }
  ];
}
