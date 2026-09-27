{ inputs, ... }:
{
  flake.modules.darwin.telegram = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.telegram.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
