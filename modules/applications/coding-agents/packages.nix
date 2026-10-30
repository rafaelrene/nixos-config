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
      names = [
        "codex"
        "claude-code"
      ];
      profiles = lib.genAttrs names (name: "${profile}-${name}");
      bundles = lib.genAttrs names (
        name:
        features.coding-agents.bundle {
          inherit pkgs;
          profile = profiles.${name};
          names = [ name ];
          legacyProfile = profile;
        }
      );
      updaters = lib.genAttrs names (
        name:
        features.coding-agents.update {
          inherit pkgs hostname name;
          profile = profiles.${name};
        }
      );
    in
    {
      inherit profiles bundles updaters;
      packages =
        lib.attrValues updaters
        ++ map (
          name:
          features.coding-agents.wrapper {
            inherit pkgs;
            profile = profiles.${name};
            legacyProfile = profile;
            name = if name == "claude-code" then "claude" else name;
            installCommand = "update-${if name == "claude-code" then "claude" else name}";
          }
        ) names;
    };
}
