{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    headful.imports = with (config.features.modulesFor platform); [
      desktop-applications
      personal-applications
      platform-desktop
    ];
    desktop-applications.imports = with (config.features.modulesFor platform); [
      ghostty
      helium
      mongodb-compass
      mpv
      obs-studio
      rustdesk
      zen
    ];
  });
}
