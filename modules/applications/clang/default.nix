let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.clang ];
  };
in
{
  flake.modules = {
    nixos.clang = common;
    darwin.clang = common;
  };
}
