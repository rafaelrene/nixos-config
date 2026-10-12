let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.gh ];
    environment.variables.GH_NO_UPDATE_NOTIFIER = "1";
  };
in
{
  flake.modules = {
    nixos.gh = common;
    darwin.gh = common;
  };
}
