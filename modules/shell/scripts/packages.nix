{ config, lib, ... }:
{
  options.features.shell.packages = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.package);
    description = "Create the shared Git and project command packages.";
  };
  config.features.shell.packages =
    { pkgs, ... }:
    let
      runtimes = config.features.shell.runtimes { inherit pkgs; };
      command =
        name:
        config.features.shell.application {
          inherit pkgs;
          inherit name;
          runtimeInputs = [
            pkgs.zsh
            pkgs.git
            pkgs.fzf
            pkgs.jq
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gawk
            pkgs.bash
          ];
          text = ''
            exec ${runtimes.zsh} -f ${./.}/${name}.zsh "$@"
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
