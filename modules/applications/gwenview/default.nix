{
  flake.modules.nixos.gwenview = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.gwenview ];
    xdg.mime.defaultApplications = {
      "image/jpeg" = "org.kde.gwenview.desktop";
      "image/png" = "org.kde.gwenview.desktop";
    };
  };
}
