{ config, ... }:
let
  inherit (config) features;
  common =
    { lib, pkgs, ... }:
    let
      theme = features.theme { inherit lib pkgs; };
    in
    {
      environment = {
        systemPackages = [ pkgs.mpv ];
        etc."mpv/mpv.conf".text = ''
          osd-font="${theme.font.interface}"
          osd-color="#${theme.colors.text}"
          osd-back-color="#${theme.colors.mantle}"
          osd-border-color="#${theme.colors.crust}"
          background-color="#${theme.colors.base}"
        '';
      };
    };
in
{
  flake.modules = {
    nixos.mpv = {
      imports = [ common ];
      xdg.mime.defaultApplications."video/mp4" = "mpv.desktop";
    };
    darwin.mpv = common;
  };
}
