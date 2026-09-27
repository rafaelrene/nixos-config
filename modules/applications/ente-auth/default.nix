{ inputs, ... }:
{
  flake.modules.darwin.ente-auth = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.ente-auth.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
