{ config, ... }:
let
  inherit (config) features;
  renderTheme =
    { lib, pkgs }:
    let
      theme = features.theme { inherit lib pkgs; };
    in
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
  common = { lib, pkgs, ... }: {
    environment = {
      systemPackages = [ pkgs.fzf ];
      variables.FZF_DEFAULT_OPTS = renderTheme { inherit lib pkgs; };
    };
  };
in
{
  flake.modules = {
    nixos.fzf = common;
    darwin.fzf = common;
  };
}
