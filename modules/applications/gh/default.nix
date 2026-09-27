let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.gh ];
  };
in
{
  flake.modules = {
    nixos.gh = common;
    darwin.gh = common;
  };
}
