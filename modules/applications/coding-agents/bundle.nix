{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.coding-agents.bundle = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build one coding-agent generation from a prefetched flake source.";
  };

  config = {
    features.coding-agents.bundle =
      { pkgs, source }:
      let
        # getFlake loads package definitions without applying upstream nixConfig.
        agents = builtins.getFlake "path:${source.path}?narHash=${lib.escapeURL source.hash}";
        packages = agents.packages.${pkgs.stdenv.hostPlatform.system};
        selected = with packages; [
          codex
          claude-code
          opencode
        ];
        release = {
          source = {
            path = agents.outPath;
            inherit (source) hash;
          };
          versions = lib.genAttrs [ "codex" "claude-code" "opencode" ] (name: packages.${name}.version);
        };
      in
      pkgs.buildEnv {
        name = "llm-agents";
        paths = selected ++ [
          (pkgs.writeTextDir "share/llm-agents/release.json" (builtins.toJSON release))
        ];
      };

    perSystem =
      { pkgs, system, ... }:
      let
        agentPkgs =
          if system == "aarch64-darwin" then import inputs.nixpkgs-darwin { inherit system; } else pkgs;
      in
      {
        legacyPackages.llmAgentsForSource =
          source:
          config.features.coding-agents.bundle {
            pkgs = agentPkgs;
            inherit source;
          };
      };
  };
}
