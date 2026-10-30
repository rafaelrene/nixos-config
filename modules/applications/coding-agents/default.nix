{ config, lib, ... }:
let
  inherit (config) features;
in
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    coding-agents =
      { config, pkgs, ... }:
      let
        home = config.users.users.${config.workstation.user}.home;
        profile = "${home}/.local/state/nix/profiles/llm-agents";
        agents = features.coding-agents.packages {
          inherit pkgs profile;
          hostname = config.networking.hostName;
        };
      in
      {
        imports = with (features.modulesFor platform); [
          codex
          claude
        ];
        system.build = agents.bundles // {
          codexUpdater = agents.updaters.codex;
          claudeUpdater = agents.updaters.claude-code;
          # An installed pre-split updater may still stage this output during the first switch.
          llm-agents = features.coding-agents.bundle { inherit pkgs profile; };
        };
        environment.systemPackages = agents.packages;
      };
  });
}
