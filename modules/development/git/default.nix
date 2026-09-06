{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.git
    pkgs.gh
  ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/git 0700 raf raf - -"
    "L+ /home/raf/.config/git/config - - - - /data/code/nixos-config/modules/development/git/config"
  ];
}
