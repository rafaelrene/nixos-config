{ inputs, ... }:
{
  flake.modules.darwin.gifox = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.gifox.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
