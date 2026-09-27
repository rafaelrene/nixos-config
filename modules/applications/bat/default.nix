let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.bat ];
  };
in
{
  flake.modules = {
    nixos.bat = common;
    darwin.bat = common;
  };
}
