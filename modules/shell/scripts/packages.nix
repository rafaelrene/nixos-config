{ pkgs, ... }:
let
  branches = pkgs.writeShellApplication {
    name = "git-branches";
    runtimeInputs = [
      pkgs.git
      pkgs.gawk
      pkgs.gnused
      pkgs.fzf
    ];
    # Keep the imported script's exit and cancellation behavior.
    bashOptions = [ ];
    text = builtins.readFile ./git-branches;
  };
  deleteBranches = pkgs.writeShellApplication {
    name = "git-delete-branches";
    runtimeInputs = [
      pkgs.git
      pkgs.fzf
    ];
    bashOptions = [ ];
    text = builtins.readFile ./git-delete-branches;
  };
  prun = pkgs.writeShellApplication {
    name = "prun";
    runtimeInputs = [
      pkgs.nushell
      pkgs.git
      pkgs.fzf
    ];
    text = ''
      exec nu --no-config-file ${./prun.nu} "$@"
    '';
  };
in
{
  inherit branches deleteBranches prun;
}
