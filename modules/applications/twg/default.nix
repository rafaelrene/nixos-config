{ config, ... }:
let
  inherit (config) features;
  common =
    { lib, pkgs, ... }:
    let
      twg = pkgs.callPackage ./_package.nix { };
      writeApplication =
        if pkgs.stdenv.hostPlatform.isDarwin then
          args: features.shell.darwinApplication (args // { inherit pkgs; })
        else
          pkgs.writeShellApplication;
    in
    {
      # TWG only notifies about upgrades. Nix manages the binary.
      environment.systemPackages = [
        (writeApplication {
          name = "twg";
          text = ''
            exec ${features.bitbucket.command pkgs} twg ${lib.getExe twg} "$@"
          '';
        })
      ];
    };
in
{
  flake.modules.nixos.twg = common;
  flake.modules.darwin.twg = common;
}
