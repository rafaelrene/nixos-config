let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.gnutar ];
  };
in
{
  flake.modules = {
    nixos.gnutar = common;
    darwin.gnutar = common;
  };
}
