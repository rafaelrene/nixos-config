{ config, ... }:
let
  inherit (config) features;
  common =
    { config, pkgs, ... }:
    let
      home = config.users.users.${config.workstation.user}.home;
    in
    {
      environment.variables.CLAUDE_CONFIG_DIR =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${home}/.local/share/claude"
        else
          "$HOME/.local/share/claude";
    };
in
{
  flake.modules = {
    nixos.claude =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        user = config.workstation.user;
        home = config.users.users.${user}.home;
        group = config.users.users.${user}.group;
        source = features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = ./settings.json;
        };
        inherit (features.coding-agents.themes { inherit lib pkgs; }) claudeTheme;
      in
      {
        imports = [ common ];
        systemd.tmpfiles.rules = [
          "d ${home}/.local/share/claude 0700 ${user} ${group} - -"
          "L+ ${home}/.local/share/claude/settings.json - - - - ${source}"
          "d ${home}/.local/share/claude/themes 0700 ${user} ${group} - -"
          "L+ ${home}/.local/share/claude/themes/workstation.json - - - - ${claudeTheme}"
        ];
      };
    darwin.claude =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        source = features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = ./settings.json;
        };
        inherit (features.coding-agents.themes { inherit lib pkgs; }) claudeTheme;
      in
      {
        imports = [ common ];
        workstation = {
          stateAliases.".local/share/claude" = ".claude";
          links = {
            ".local/share/claude/settings.json" = source;
            ".local/share/claude/themes/workstation.json" = toString claudeTheme;
          };
        };
      };
  };
}
