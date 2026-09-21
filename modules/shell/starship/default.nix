{ lib, pkgs, ... }:
let
  starshipConfig = import ./config.nix { inherit lib pkgs; };
in
{
  environment.systemPackages = [ pkgs.starship ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/starship 0700 raf raf - -"
    "L+ /home/raf/.config/starship/starship.toml - - - - ${starshipConfig}"
  ];
}
