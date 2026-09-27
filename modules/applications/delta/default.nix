let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.delta ];
  };
in
{
  flake.modules = {
    nixos.delta = common;
    darwin.delta = common;
  };
}
