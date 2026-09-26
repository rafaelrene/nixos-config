{ pkgs, ... }:
let
  inherit (import ./packages.nix { inherit pkgs; }) branches deleteBranches gitDb;
in
{
  environment.systemPackages = [
    branches
    deleteBranches
    gitDb
  ];
  systemd.tmpfiles.rules = [
    "L+ /home/raf/.local/bin/git-branches - - - - ${branches}/bin/git-branches"
    "L+ /home/raf/.local/bin/git-delete-branches - - - - ${deleteBranches}/bin/git-delete-branches"
    "L+ /home/raf/.local/bin/git-db - - - - ${deleteBranches}/bin/git-delete-branches"
  ];
}
