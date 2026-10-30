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
        profile ? null,
        names ? [
          "codex"
          "claude-code"
        ],
        legacyProfile ? null,
      }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        packages = inputs.llm-agents.packages.${system};
        selected = map (name: packages.${name}) names;
        release.versions = lib.genAttrs names (name: packages.${name}.version);
        package = pkgs.buildEnv {
          name = "llm-agents-${lib.concatStringsSep "-" names}";
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
          # Keep the old signing identity and requirements without moving credentials.
          identityState =
            if legacyProfile == null then "${profile}-identity" else "${legacyProfile}-identity";
          previousBin = if legacyProfile == null then null else "${legacyProfile}-executables/bin";
          resourceTrees = lib.optionalAttrs (builtins.elem "codex" names) {
            "${profile}-executables/codex-path" = "${packages.codex}/libexec/codex/codex-path";
            "${profile}-executables/codex-resources" = "${packages.codex}/libexec/codex/codex-resources";
          };
          resourceFiles = lib.optionalAttrs (builtins.elem "codex" names) {
            "${profile}-executables/codex-package.json" = "${packages.codex}/libexec/codex/codex-package.json";
          };
          resourceExecutableAliases = lib.optionalAttrs (builtins.elem "codex" names) {
            "${profile}-executables/codex-resources/zsh/bin/zsh" =
              (config.features.shell.runtimes { inherit pkgs; }).zsh;
          };
        }
      else
        package;

    perSystem =
      { pkgs, ... }:
      {
        packages.llm-agents = config.features.coding-agents.bundle { inherit pkgs; };
      };
  };
}
