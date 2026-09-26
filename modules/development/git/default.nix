{ lib, pkgs, ... }:
let
  deltaConfig = import ./theme.nix { inherit lib pkgs; };
in
{
  environment.systemPackages = [
    pkgs.git
    pkgs.delta
    pkgs.gh
    (pkgs.callPackage ./bitbucket.nix { })
  ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/git 0700 raf raf - -"
    "L+ /home/raf/.config/git/config - - - - /data/code/nixos-config/modules/development/git/config"
    "L+ /home/raf/.config/git/themes.gitconfig - - - - ${deltaConfig}"
    "L+ /home/raf/.config/git/ignore - - - - /data/code/nixos-config/modules/development/git/ignore"
  ];
}
