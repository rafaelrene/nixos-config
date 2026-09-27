let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.yazi ];
  };
in
{
  flake.modules = {
    nixos.yazi = common;
    darwin.yazi = common;
  };
}
