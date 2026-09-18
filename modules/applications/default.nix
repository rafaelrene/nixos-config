{ lib, pkgs, ... }:
let
  theme = import ../../themes { inherit lib pkgs; };
in
{
  imports = [
    ./ghostty
    ./helium
    ./zen
    ./neovim
    ./tealdeer
    ./vicinae
    ./t3code
    ./webapps
  ];
  environment = {
    systemPackages = with pkgs; [
      ffmpegthumbnailer
      kdePackages.ark
      kdePackages.dolphin
      kdePackages.gwenview
      kdePackages.kdegraphics-thumbnailers
      kdePackages.kio-extras
      kdePackages.okular
      mpv
    ];
    etc = {
      "xdg/mimeapps.list".text = ''
        [Default Applications]
        text/html=helium.desktop
        x-scheme-handler/http=helium.desktop
        x-scheme-handler/https=helium.desktop
        x-scheme-handler/about=helium.desktop
        x-scheme-handler/unknown=helium.desktop
        application/pdf=org.kde.okular.desktop
        image/jpeg=org.kde.gwenview.desktop
        image/png=org.kde.gwenview.desktop
        video/mp4=mpv.desktop
        inode/directory=org.kde.dolphin.desktop
      '';
      "mpv/mpv.conf".text = ''
        osd-font="${theme.font.interface}"
        osd-color="#${theme.colors.text}"
        osd-back-color="#${theme.colors.mantle}"
        osd-border-color="#${theme.colors.crust}"
        background-color="#${theme.colors.base}"
      '';
    };
  };
}
