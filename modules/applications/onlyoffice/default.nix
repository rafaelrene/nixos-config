{ inputs, ... }:
{
  flake.modules.darwin.onlyoffice = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.onlyoffice.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
