{ inputs, ... }:
{
  flake.modules.darwin.standard-notes = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.standard-notes.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
