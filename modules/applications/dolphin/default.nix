{
  flake.modules.nixos.dolphin = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.dolphin ];
    xdg.mime.defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
    };
  };
}
