let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.jq ];
  };
in
{
  flake.modules = {
    nixos.jq = common;
    darwin.jq = common;
  };
}
