{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
in
{
  environment.systemPackages = [ pkgs.ghostty ];
  environment.etc."xdg/ghostty/theme".text = ''
    font-family = ${theme.font.monospace}
    theme = ${theme.ghostty}
  '';
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/ghostty 0700 raf raf - -"
    "L+ /home/raf/.config/ghostty/config - - - - /data/code/nixos-config/modules/applications/ghostty/config"
  ];
}
