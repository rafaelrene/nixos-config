{ inputs, ... }:
{
  flake.modules.darwin.signal = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.signal.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
