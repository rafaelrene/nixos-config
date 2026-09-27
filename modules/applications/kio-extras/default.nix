{
  flake.modules.nixos.kio-extras = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.kio-extras ];
  };
}
