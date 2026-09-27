{
  flake.modules.nixos.brightnessctl = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.brightnessctl ];
  };
}
