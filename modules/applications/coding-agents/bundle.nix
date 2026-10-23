{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.coding-agents.bundle = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build one coding-agent generation from maintained Nix packages.";
  };

  config = {
    features.coding-agents.bundle =
      {
        pkgs,
        source ? null,
        profile ? null,
      }:
      let
        # Retain the old recipe only for stable-identity migration of existing profiles.
        agents =
          if source == null then
            inputs.llm-agents
          else
            builtins.getFlake "path:${source.path}?narHash=${lib.escapeURL source.hash}";
        system = pkgs.stdenv.hostPlatform.system;
        claude = source.releases.claude-code;
        claudeSource =
          system:
          pkgs.fetchurl {
            url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${claude.version}/${
              {
                aarch64-darwin = "darwin-arm64";
                x86_64-linux = "linux-x64";
              }
              .${system}
            }/claude";
            sha256 = claude.hashes.${system};
          };
        packages =
          agents.packages.${system}
          // lib.optionalAttrs (source != null) {
            codex = config.features.coding-agents.codex {
              inherit pkgs;
              release = source.releases.codex;
            };
            claude-code = agents.packages.${system}.claude-code.overrideAttrs {
              inherit (claude) version;
              src = claudeSource system;
              codesignSources = [ (claudeSource "aarch64-darwin") ];
            };
          };
        selected = with packages; [
          codex
          claude-code
        ];
        release = {
          source = {
            path = agents.outPath;
            hash = if source == null then agents.narHash else source.hash;
          };
          versions = lib.genAttrs [ "codex" "claude-code" ] (name: packages.${name}.version);
        }
        // lib.optionalAttrs (source != null) { inherit (source) releases; };
        package = pkgs.buildEnv {
          name = "llm-agents";
          paths = selected ++ [
            (pkgs.writeTextDir "share/llm-agents/release.json" (builtins.toJSON release))
          ];
        };
      in
      if pkgs.stdenv.hostPlatform.isDarwin && profile != null then
        config.features.shell.darwinUserIdentity {
          inherit pkgs package;
          bin = "${profile}-executables/bin";
          state = "${profile}-identity";
          resourceTrees = {
            "${profile}-executables/codex-path" = "${packages.codex}/libexec/codex/codex-path";
            "${profile}-executables/codex-resources" = "${packages.codex}/libexec/codex/codex-resources";
          };
          resourceFiles."${profile}-executables/codex-package.json" =
            "${packages.codex}/libexec/codex/codex-package.json";
          resourceExecutableAliases."${profile}-executables/codex-resources/zsh/bin/zsh" =
            (config.features.shell.runtimes { inherit pkgs; }).zsh;
        }
      else
        package;

    perSystem =
      { pkgs, ... }:
      {
        legacyPackages.llmAgentsForSource =
          source:
          config.features.coding-agents.bundle {
            inherit pkgs source;
            profile = source.profile or null;
          };
      };
  };
}
