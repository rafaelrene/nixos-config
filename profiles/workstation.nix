{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    workstation.imports =
      (with (config.features.modulesFor platform); [
        workstation-options
        system
        fonts
        updates
      ])
      ++ lib.optional (platform == "darwin") (config.features.modulesFor "darwin").user-files;
  });
}
