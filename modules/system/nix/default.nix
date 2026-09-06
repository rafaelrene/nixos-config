{
  config,
  lib,
  pkgs,
  ...
}:
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

  environment.variables.NH_FLAKE = "/data/code/nixos-config";
  environment.systemPackages = [ pkgs.nh ];
  assertions = [
    {
      assertion = config.nix.settings.trusted-users == [ "root" ];
      message = "Only root may be a trusted Nix user on Othinus.";
    }
  ];
}
