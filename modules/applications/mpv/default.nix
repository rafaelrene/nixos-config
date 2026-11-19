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
    darwin.mpv = {
      imports = [
        common
        (features.modulesFor "darwin").desktop-session
      ];
      workstation.desktop.defaultApplications = ''
        io.mpv public.movie all
        io.mpv public.audio all
        io.mpv public.mpeg-4 all
        io.mpv com.apple.quicktime-movie all
        io.mpv public.avi all
        io.mpv public.mp3 all
        io.mpv public.mpeg-4-audio all
        io.mpv org.xiph.flac all
        io.mpv com.microsoft.waveform-audio all
        io.mpv org.matroska.mkv all
        io.mpv org.webmproject.webm all
      '';
    };
  };
}
