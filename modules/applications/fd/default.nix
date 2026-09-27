let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.fd ];
  };
in
{
  flake.modules = {
    nixos.fd = common;
    darwin.fd = common;
  };
}
