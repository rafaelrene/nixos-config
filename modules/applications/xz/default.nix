let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.xz ];
  };
in
{
  flake.modules = {
    nixos.xz = common;
    darwin.xz = common;
  };
}
