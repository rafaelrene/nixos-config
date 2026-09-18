{ lib, pkgs, ... }:
let
  theme = import ../../themes { inherit lib pkgs; };
in
{
  imports = [
    ./nushell
    ./scripts
    ./starship
  ];
  programs.bash.completion.enable = true;
  environment.variables.FZF_DEFAULT_OPTS =
    "--color="
    + lib.concatStringsSep "," (
      lib.mapAttrsToList (role: color: "${role}:#${color}") {
        bg = theme.colors.base;
        "bg+" = theme.colors.surface0;
        fg = theme.colors.text;
        "fg+" = theme.colors.text;
        hl = theme.accentColor;
        "hl+" = theme.accentColor;
        prompt = theme.accentColor;
        pointer = theme.accentColor;
        marker = theme.accentColor;
        border = theme.colors.surface2;
        info = theme.colors.subtext0;
        header = theme.colors.blue;
        spinner = theme.colors.lavender;
      }
    );
}
