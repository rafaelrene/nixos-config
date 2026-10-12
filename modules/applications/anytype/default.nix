{ inputs, config, ... }:
{
  flake.modules.darwin.anytype = { pkgs, ... }: {
    imports = [ (config.features.updates.darwinAppSettings "anytype") ];
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.anytype.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
