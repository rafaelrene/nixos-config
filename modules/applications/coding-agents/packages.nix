{ config, lib, ... }:
let
  inherit (config) features;
in
{
  options.features.coding-agents.packages = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Build the shared agent wrappers and profile updater.";
  };

  config.features.coding-agents.packages =
    {
      pkgs,
      profile,
      installCommand ? "update-llm-agents",
    }:
    let
      updater = features.coding-agents.update { inherit pkgs profile; };
    in
    {
      inherit updater;
      packages = [
        updater
      ]
      ++
        map
          (
            name:
            features.coding-agents.wrapper {
              inherit
                pkgs
                profile
                name
                installCommand
                ;
            }
          )
          [
            "claude"
            "codex"
            "opencode"
          ];
    };
}
