let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.zip ];
  };
in
{
  flake.modules = {
    nixos.zip = common;
    darwin.zip = common;
  };
}
