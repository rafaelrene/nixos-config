{ inputs, ... }:
{
  flake.modules.darwin.ungoogled-chromium = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.ungoogled-chromium.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
