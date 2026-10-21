let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.acli ];
    # ACLI's update notices have no documented opt-out; Nix manages the binary.
  };
in
{
  flake.modules = {
    nixos.acli = common;
    darwin.acli = common;
  };
}
