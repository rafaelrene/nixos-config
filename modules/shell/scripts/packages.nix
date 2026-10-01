{ lib, ... }:
{
  options.features.shell.packages = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.package);
    description = "Create the shared Git and project command packages.";
  };
  config.features.shell.packages =
    { pkgs, ... }:
    let
      command =
        name:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [
            pkgs.nushell
            pkgs.git
            pkgs.fzf
            pkgs.bash
          ];
          text = ''
            exec nu --no-config-file ${./.}/${name}.nu "$@"
          '';
        };
    in
    {
      deleteBranches = (command "git-delete-branches").overrideAttrs (previous: {
        buildCommand = previous.buildCommand + ''
          ln -s git-delete-branches "$out/bin/git-db"
        '';
      });
      project-run = command "project-run";
    };
}
