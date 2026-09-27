{
  flake.modules.nixos.okular = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.okular ];
    xdg.mime.defaultApplications = {
      "application/pdf" = "org.kde.okular.desktop";
    };
  };
}
