{ lib, pkgs }:
let
  theme = import ../../../themes { inherit lib pkgs; };
in
pkgs.writeText "delta.gitconfig" (lib.generators.toGitINI { inherit (theme) delta; })
