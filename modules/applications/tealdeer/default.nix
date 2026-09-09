{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.tealdeer ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/tealdeer 0755 raf raf - -"
    "L+ /home/raf/.config/tealdeer/config.toml - - - - ${./config.toml}"
  ];
}
