{ inputs, ... }:
{
  # Native updater disablement has not been verified for this application.
  flake.modules.darwin.ente = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.ente.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
