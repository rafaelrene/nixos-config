{
  flake.modules.nixos.ffmpegthumbnailer = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ffmpegthumbnailer ];
  };
}
