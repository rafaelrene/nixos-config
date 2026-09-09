{ lib, pkgs, ... }:
let
  theme = import ../../../themes { inherit lib pkgs; };
  deltaConfig = pkgs.writeText "delta.gitconfig" (lib.generators.toGitINI { inherit (theme) delta; });
in
{
  environment.systemPackages = [
    pkgs.git
    pkgs.delta
    pkgs.gh
  ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/git 0700 raf raf - -"
    "L+ /home/raf/.config/git/config - - - - /data/code/nixos-config/modules/development/git/config"
    "L+ /home/raf/.config/git/themes.gitconfig - - - - ${deltaConfig}"
    "L+ /home/raf/.config/git/ignore - - - - /data/code/nixos-config/modules/development/git/ignore"
  ];
}
