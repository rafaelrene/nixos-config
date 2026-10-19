{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    desktop-workstation.imports = with (config.features.modulesFor platform); [
      development
      personal-applications
      platform-desktop
    ];
  });
}
