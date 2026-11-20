{ config, ... }:
{
  flake.modules.nixos.platform-desktop.imports = with (config.features.modulesFor "nixos"); [
    desktop
    desktop-theme
    niri
    dms
    ffmpegthumbnailer
    ark
    dolphin
    gwenview
    kdegraphics-thumbnailers
    kio-extras
    okular
    satty
    vicinae
    wl-clipboard
    wl-screenrec
    xwayland-satellite
  ];
  flake.modules.darwin.platform-desktop.imports = with (config.features.modulesFor "darwin"); [
    desktop
    remote-desktop
    gifox
    omniwm
    raycast
    shottr
    skhd
    thaw
    typewhisper
    yaak
  ];
}
