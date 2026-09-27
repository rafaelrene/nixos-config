let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.lsof ];
  };
in
{
  flake.modules = {
    nixos.lsof = common;
    darwin.lsof = common;
  };
}
