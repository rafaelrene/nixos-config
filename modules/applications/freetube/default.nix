{ config, ... }:
{
  flake.modules.darwin.freetube = { pkgs, ... }: {
    imports = [
      (config.features.updates.darwinAppSettings {
        process = "FreeTube";
        directory = "Library/Application Support/FreeTube";
        prepare = ./settings.py;
      })
    ];
    environment.systemPackages = [ pkgs.freetube ];
  };
}
