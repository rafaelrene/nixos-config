let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.nodejs_24 ];
  };
in
{
  flake.modules = {
    nixos.nodejs = common;
    darwin.nodejs = common;
  };
}
