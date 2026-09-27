{ inputs, ... }:
{
  flake.modules.darwin.anytype = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.anytype.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
