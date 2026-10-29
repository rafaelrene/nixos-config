{ config, lib, ... }:
{
  options.features.nix.withGithubAuth = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Run a Nix command with the workstation user's GitHub CLI credential.";
  };

  config.features.nix.withGithubAuth =
    { pkgs }:
    config.features.shell.application {
      inherit pkgs;
      name = "with-nix-github-auth";
      runtimeInputs = [ pkgs.gh ];
      text = builtins.readFile ./github-auth.sh;
    };
}
