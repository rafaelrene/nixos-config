let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.wget ];
  };
in
{
  flake.modules = {
    nixos.wget = common;
    darwin.wget = common;
  };
}
