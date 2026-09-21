{ lib, pkgs, ... }:
let
  nuConfig = import ./config.nix { inherit lib pkgs; };
in
{
  users.users.raf.shell = pkgs.nushell;
  environment.systemPackages = [
    pkgs.eza
    pkgs.zoxide
  ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/nushell 0700 raf raf - -"
    "L+ /home/raf/.config/nushell/config.nu - - - - ${nuConfig}"
  ];
}
