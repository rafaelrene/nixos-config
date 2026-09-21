{ lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.ghostty ];
  environment.etc."xdg/ghostty/theme".text = import ./theme.nix { inherit lib pkgs; };
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/ghostty 0700 raf raf - -"
    "L+ /home/raf/.config/ghostty/config - - - - /data/code/nixos-config/modules/applications/ghostty/config"
  ];
}
