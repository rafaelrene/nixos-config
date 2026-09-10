{ lib, pkgs, ... }:
let
  displayResolution = "2560x1440";
  wallpaperSource = ../../../wallpapers;
  wallpaperFiles = builtins.readDir wallpaperSource;
  # Resolution variants belong to their original, never to a separate rotation entry.
  originals = builtins.filter (
    name:
    wallpaperFiles.${name} == "regular"
    && builtins.match ".*\\.(jpg|jpeg|png|webp)" name != null
    && builtins.match ".*-[0-9]+x[0-9]+\\.[^.]+" name == null
  ) (builtins.attrNames wallpaperFiles);
  wallpapers = pkgs.linkFarm "wallpapers" (
    map (
      original:
      let
        parts = builtins.match "(.*)\\.([^.]+)" original;
        variant = "${builtins.elemAt parts 0}-${displayResolution}.${builtins.elemAt parts 1}";
        selected = if wallpaperFiles.${variant} or null == "regular" then variant else original;
      in
      {
        name = selected;
        path = wallpaperSource + "/${selected}";
      }
    ) originals
  );
  theme = import ../../../themes { inherit lib pkgs; };
  niriConfig = pkgs.writeText "niri-config.kdl" (
    lib.replaceStrings
      [ "@accent@" "@surface2@" "@urgent@" "@displayResolution@" ]
      [ theme.accentColor theme.colors.surface2 theme.colors.red displayResolution ]
      (builtins.readFile ./config.kdl)
  );
in
{
  programs.niri = {
    enable = true;
    useNautilus = false;
  };
  services.displayManager.defaultSession = "niri";
  xdg.portal.config.niri."org.freedesktop.impl.portal.Settings" = [ "gtk" ];
  environment.systemPackages = [ pkgs.xwayland-satellite ];
  systemd.tmpfiles.rules = [
    "d /home/raf/Pictures 0755 raf raf - -"
    "d /home/raf/Pictures/Screenshots 0755 raf raf - -"
    "L+ /home/raf/Pictures/Wallpapers - - - - ${wallpapers}"
    "d /home/raf/.config/niri 0700 raf raf - -"
    "L+ /home/raf/.config/niri/config.kdl - - - - ${niriConfig}"
  ];
}
