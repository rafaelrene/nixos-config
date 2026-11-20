{ config, lib, ... }:
let
  inherit (config) features;
in
{
  options.features.coding-agents.packages = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Build independent agent profiles, updaters and launchers.";
  };

  config.features.coding-agents.packages =
    {
      pkgs,
      profile,
      hostname,
    }:
    let
      agents = {
        codex = {
          executable = "codex";
          title = "Codex";
          legacyProfile = profile;
        };
        claude-code = {
          executable = "claude";
          title = "Claude Code";
          legacyProfile = profile;
        };
        antigravity-cli = {
          executable = "agy";
          title = "Antigravity";
        };
      };
      profiles = lib.mapAttrs (name: _: "${profile}-${name}") agents;
      bundles = lib.mapAttrs (
        name: agent:
        features.coding-agents.bundle {
          inherit pkgs;
          profile = profiles.${name};
          names = [ name ];
          legacyProfile = agent.legacyProfile or null;
        }
      ) agents;
      updaters = lib.mapAttrs (
        name: agent:
        features.coding-agents.update {
          inherit pkgs hostname name;
          inherit (agent) title;
          commandName = "update-${agent.executable}";
          profile = profiles.${name};
          initial =
            if pkgs.stdenv.hostPlatform.isDarwin || !(agent ? legacyProfile) then bundles.${name} else null;
        }
      ) agents;
    in
    {
      inherit profiles bundles updaters;
      packages =
        lib.attrValues updaters
        ++ lib.mapAttrsToList (
          name: agent:
          features.coding-agents.wrapper {
            inherit pkgs;
            profile = profiles.${name};
            legacyProfile = agent.legacyProfile or null;
            name = agent.executable;
            installCommand = lib.getName updaters.${name};
          }
        ) agents;
    };
}
