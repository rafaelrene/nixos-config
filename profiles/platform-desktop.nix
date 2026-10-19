{ config, ... }:
{
  flake.modules.nixos.platform-desktop.imports = with (config.features.modulesFor "nixos"); [
    desktop
    desktop-theme
    niri
    dms
    ghostty
    t3code
    brightnessctl
    ffmpegthumbnailer
    ark
    dolphin
    gwenview
    kdegraphics-thumbnailers
    kio-extras
    okular
    p7zip
    pciutils
    satty
    usbutils
    vicinae
    wl-clipboard
    xwayland-satellite
  ];
  flake.modules.darwin.platform-desktop.imports = with (config.features.modulesFor "darwin"); [
    ghostty
    gifox
    omniwm
    raycast
    shottr
    skhd
    thaw
    typewhisper
  ];
}
