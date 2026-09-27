{
  flake.modules.nixos.usbutils = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.usbutils ];
  };
}
