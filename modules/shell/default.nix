{ lib, pkgs, ... }:
{
  imports = [
    ./nushell
    ./scripts
    ./starship
  ];
  programs.bash.completion.enable = true;
  environment.variables.FZF_DEFAULT_OPTS = import ./fzf.nix { inherit lib pkgs; };
}
