{ config, lib, ... }:
let
  inherit (config) features;
  setup =
    { pkgs, ... }:
    let
      writeApplication =
        if pkgs.stdenv.hostPlatform.isDarwin then
          args: features.shell.darwinApplication (args // { inherit pkgs; })
        else
          pkgs.writeShellApplication;
    in
    {
      environment.systemPackages = [
        (writeApplication {
          name = "bitbucket-setup";
          text = ''
            exec ${features.bitbucket.command pkgs} setup "$@"
          '';
        })
      ];
    };
in
{
  options.features.bitbucket.command = lib.mkOption {
    type = lib.types.functionTo lib.types.str;
    description = "Run the local Bitbucket credential helper.";
  };
  config = {
    features.bitbucket.command = pkgs: "${lib.getExe pkgs.python3} ${./credentials.py}";
    flake.modules = {
      nixos.bitbucket = setup;
      darwin.bitbucket = setup;
    };
  };
}
