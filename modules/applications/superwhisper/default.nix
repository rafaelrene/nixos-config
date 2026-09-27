{ inputs, ... }:
{
  flake.modules.darwin.superwhisper = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.superwhisper.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
