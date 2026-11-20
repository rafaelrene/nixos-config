let
  common = { pkgs, ... }: {
    # TWG only notifies about upgrades. Nix manages the binary.
    environment.systemPackages = [ (pkgs.callPackage ./_package.nix { }) ];
  };
in
{
  flake.modules.nixos.twg = common;
  flake.modules.darwin.twg = common;
}
