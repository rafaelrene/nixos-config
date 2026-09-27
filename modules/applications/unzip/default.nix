let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.unzip ];
  };
in
{
  flake.modules = {
    nixos.unzip = common;
    darwin.unzip = common;
  };
}
