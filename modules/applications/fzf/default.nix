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
    # Load only history bindings after the workstation's bindkey -v setup.
    programs.zsh.interactiveShellInit = ''
      FZF_CTRL_T_COMMAND= FZF_ALT_C_COMMAND= source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      bindkey -M viins '^R' fzf-history-widget
      bindkey -M vicmd '^R' fzf-history-widget
    '';
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
