{
  flake.modules.nixos.kdegraphics-thumbnailers = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.kdegraphics-thumbnailers ];
  };
}
