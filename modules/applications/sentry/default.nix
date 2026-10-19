let
  common = { pkgs, ... }: {
    environment.systemPackages = [ (pkgs.callPackage ./_package.nix { }) ];
    environment.variables.SENTRY_CLI_NO_UPDATE_CHECK = "1";
  };
in
{
  flake.modules.nixos.sentry = common;
  flake.modules.darwin.sentry = common;
}
