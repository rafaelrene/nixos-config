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
      pkgs.gnused
    ];
    bashOptions = [ ];
    text = builtins.readFile ./git-delete-branches;
  };
in
{
  systemd.tmpfiles.rules = [
    "L+ /home/raf/.local/bin/git-branches - - - - ${branches}/bin/git-branches"
    "L+ /home/raf/.local/bin/git-delete-branches - - - - ${deleteBranches}/bin/git-delete-branches"
    "L+ /home/raf/.local/bin/git-db - - - - ${deleteBranches}/bin/git-delete-branches"
  ];
}
