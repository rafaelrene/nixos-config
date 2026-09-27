{ inputs, ... }:
let
  shared = { pkgs, ... }: {
    environment.systemPackages = [
      (
        if pkgs.stdenv.hostPlatform.isDarwin then
          inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.mongodb-compass.overrideAttrs {
            dontFixup = true;
          }
        else
          pkgs.mongodb-compass
      )
    ];
  };
in
{
  flake.modules = {
    nixos.mongodb-compass = shared;
    darwin.mongodb-compass = shared;
  };
}
