{ config, ... }:
{
  flake.modules.darwin.freetube = { pkgs, ... }: {
    imports = [ (config.features.updates.darwinAppSettings "freetube") ];
    environment.systemPackages = [ pkgs.freetube ];
  };
}
