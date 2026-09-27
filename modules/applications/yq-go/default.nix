let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.yq-go ];
  };
in
{
  flake.modules = {
    nixos.yq-go = common;
    darwin.yq-go = common;
  };
}
