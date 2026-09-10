{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  niriConfig = pkgs.writeText "niri-config.kdl" (
    lib.replaceStrings
      [ "@accent@" "@surface2@" "@urgent@" ]
      [ theme.accentColor theme.colors.surface2 theme.colors.red ]
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
    "L+ /home/raf/Pictures/Wallpapers - - - - ${../../../wallpapers}"
    "d /home/raf/.config/niri 0700 raf raf - -"
    "L+ /home/raf/.config/niri/config.kdl - - - - ${niriConfig}"
  ];
}
