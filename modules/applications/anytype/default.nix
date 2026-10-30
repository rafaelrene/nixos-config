{ inputs, config, ... }:
{
  flake.modules.darwin.anytype = { pkgs, ... }: {
    imports = [
      (config.features.updates.darwinAppSettings {
        process = "Anytype";
        directory = "Library/Application Support/anytype";
        files."devconfig.json" = {
          format = "json";
          settings.updateDisabled = true;
        };
      })
    ];
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.anytype.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
