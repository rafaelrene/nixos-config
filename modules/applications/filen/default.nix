{ inputs, ... }:
{
  flake.modules.darwin.filen = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.filen.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
