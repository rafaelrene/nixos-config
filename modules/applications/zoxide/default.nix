let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.zoxide ];
  };
in
{
  flake.modules = {
    nixos.zoxide = common;
    darwin.zoxide = common;
  };
}
