let
  common = { pkgs, ... }: {
    environment.systemPackages = [ (pkgs.callPackage ./_package.nix { }) ];
  };
in
{
  flake.modules.nixos.bkt = common;
  flake.modules.darwin.bkt = common;
}
