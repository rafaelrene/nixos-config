{ pkgs, ... }: {
  imports = [
    ./ghostty
    ./helium
    ./zen
    ./neovim
    ./vicinae
  ];
  environment.systemPackages = with pkgs; [
    ffmpegthumbnailer
    kdePackages.ark
    kdePackages.dolphin
    kdePackages.gwenview
    kdePackages.kdegraphics-thumbnailers
    kdePackages.kio-extras
    kdePackages.okular
    mpv
  ];
  environment.etc."xdg/mimeapps.list".text = ''
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
}
