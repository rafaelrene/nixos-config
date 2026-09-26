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
in
{
  inherit branches deleteBranches;
  gitDb = pkgs.linkFarm "git-db" [
    {
      name = "bin/git-db";
      path = "${deleteBranches}/bin/git-delete-branches";
    }
  ];
}
