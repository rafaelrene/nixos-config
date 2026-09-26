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
  branches = command "git-branches";
  deleteBranches = (command "git-delete-branches").overrideAttrs (previous: {
    buildCommand = previous.buildCommand + ''
      ln -s git-delete-branches "$out/bin/git-db"
    '';
  });
  prun = command "prun";
}
