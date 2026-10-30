{ config, ... }:
let
  inherit (config) features;
  common =
    { config, pkgs, ... }:
    let
      home = config.users.users.${config.workstation.user}.home;
    in
    {
      environment = {
        variables.CODEX_HOME =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "${home}/.local/share/codex"
          else
            "$HOME/.local/share/codex";
        etc."codex/requirements.toml".text = ''
          check_for_update_on_startup = false
        '';
      };
    };
in
{
  flake.modules = {
    nixos.codex =
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
          source = ./config.toml;
        };
        inherit (features.coding-agents.themes { inherit lib pkgs; }) codexTheme;
      in
      {
        imports = [ common ];
        systemd.tmpfiles.rules = [
          "d ${home}/.local/share/codex 0700 ${user} ${group} - -"
          "L+ ${home}/.local/share/codex/config.toml - - - - ${source}"
          "d ${home}/.local/share/codex/themes 0700 ${user} ${group} - -"
          "L+ ${home}/.local/share/codex/themes/workstation.tmTheme - - - - ${codexTheme}"
        ];
      };
    darwin.codex =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        source = features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = ./config.toml;
        };
        inherit (features.coding-agents.themes { inherit lib pkgs; }) codexTheme;
      in
      {
        imports = [ common ];
        workstation = {
          stateAliases.".local/share/codex" = ".codex";
          links = {
            ".local/share/codex/config.toml" = source;
            ".local/share/codex/themes/workstation.tmTheme" = toString codexTheme;
          };
        };
      };
  };
}
