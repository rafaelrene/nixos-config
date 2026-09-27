let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.curl ];
  };
in
{
  flake.modules = {
    nixos.curl = common;
    darwin.curl = common;
  };
}
