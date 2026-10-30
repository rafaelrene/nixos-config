{ inputs, config, ... }:
{
  flake.modules.darwin.standard-notes = { pkgs, ... }: {
    imports = [
      (config.features.updates.darwinAppSettings {
        process = "Standard Notes";
        directory = "Library/Application Support/Standard Notes";
        files."user-preferences.json" = {
          format = "json";
          settings.enableAutoUpdates = false;
        };
      })
    ];
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.standard-notes.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
