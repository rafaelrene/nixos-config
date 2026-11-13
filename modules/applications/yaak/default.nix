{ config, inputs, ... }:
{
  flake.modules.darwin.yaak =
    { pkgs, ... }:
    {
      # First launch creates the settings database. Until then, disable updates in
      # Settings, close Yaak, and rebuild to apply the managed preference.
      imports = [
        (config.features.updates.darwinAppSettings {
          process = "yaak-app-client";
          directory = "Library/Application Support/app.yaak.desktop";
          prepare = ./settings.py;
        })
      ];
      environment.systemPackages = [
        (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.yaak.overrideAttrs {
          dontFixup = true;
        })
      ];
    };
}
