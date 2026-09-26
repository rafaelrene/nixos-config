{ pkgs, ... }:
let
  inherit (import ./packages.nix { inherit pkgs; }) branches deleteBranches;
  destinations = import ./destinations {
    inherit pkgs;
    home = "/home/raf";
    code = "/data/code";
    hostname = "othinus";
  };
in
{
  environment.systemPackages = [ destinations ];
  systemd.tmpfiles.rules = [
    "L+ /home/raf/.local/bin/git-branches - - - - ${branches}/bin/git-branches"
    "L+ /home/raf/.local/bin/git-delete-branches - - - - ${deleteBranches}/bin/git-delete-branches"
    "L+ /home/raf/.local/bin/git-db - - - - ${deleteBranches}/bin/git-delete-branches"
  ];
}
