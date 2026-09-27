{
  flake.modules.nixos.xwayland-satellite = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.xwayland-satellite ];
  };
}
