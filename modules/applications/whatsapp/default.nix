{ inputs, ... }:
{
  # Native updater disablement has not been verified for this application.
  flake.modules.darwin.whatsapp = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.whatsapp.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
