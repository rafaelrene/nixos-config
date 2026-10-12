{ inputs, config, ... }:
{
  flake.modules.darwin.standard-notes = { pkgs, ... }: {
    imports = [ (config.features.updates.darwinAppSettings "standard-notes") ];
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.standard-notes.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
