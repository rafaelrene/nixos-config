let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.btop ];
  };
in
{
  flake.modules = {
    nixos.btop = common;
    darwin.btop = common;
  };
}
