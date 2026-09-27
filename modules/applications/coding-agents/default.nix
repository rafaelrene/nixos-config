{ config, lib, ... }:
let
  inherit (config) features;
in
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (_: {
    coding-agents =
      { config, pkgs, ... }:
      let
        home = config.users.users.${config.workstation.user}.home;
        profile = "${home}/.local/state/nix/profiles/llm-agents";
        agents = features.coding-agents.packages { inherit pkgs profile; };
        environmentHome = if pkgs.stdenv.hostPlatform.isDarwin then home else "$HOME";
      in
      {
        environment.systemPackages = agents.packages;
        environment.variables = {
          CODEX_HOME = "${environmentHome}/.local/share/codex";
          CLAUDE_CONFIG_DIR = "${environmentHome}/.local/share/claude";
        };
      };
  });
}
