let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.eza ];
  };
in
{
  flake.modules = {
    nixos.eza = common;
    darwin.eza = common;
  };
}
