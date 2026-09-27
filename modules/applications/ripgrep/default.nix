let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ripgrep ];
  };
in
{
  flake.modules = {
    nixos.ripgrep = common;
    darwin.ripgrep = common;
  };
}
