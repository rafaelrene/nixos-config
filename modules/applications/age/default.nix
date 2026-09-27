let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.age ];
  };
in
{
  flake.modules = {
    nixos.age = common;
    darwin.age = common;
  };
}
