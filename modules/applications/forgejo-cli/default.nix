let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.forgejo-cli ];
  };
in
{
  flake.modules = {
    nixos.forgejo-cli = common;
    darwin.forgejo-cli = common;
  };
}
