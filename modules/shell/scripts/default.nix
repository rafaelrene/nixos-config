{ pkgs, ... }:
let
  inherit (import ./packages.nix { inherit pkgs; }) branches deleteBranches prun;
  destinations = import ./destinations {
    inherit pkgs;
    home = "/home/raf";
    code = "/data/code";
    hostname = "othinus";
  };
in
{
  environment.systemPackages = [
    branches
    deleteBranches
    destinations
    prun
  ];
  # Remove the previously managed links so they cannot shadow system packages.
  systemd.tmpfiles.rules = [
    "r /home/raf/.local/bin/git-branches - - - -"
    "r /home/raf/.local/bin/git-delete-branches - - - -"
    "r /home/raf/.local/bin/git-db - - - -"
  ];
}
