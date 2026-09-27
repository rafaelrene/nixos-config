{ lib, ... }:
{
  options.features.coding-agents.update = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build the updater for an independent coding-agent profile.";
  };

  config.features.coding-agents.update =
    {
      pkgs,
      profile,
      flake ? "github:numtide/llm-agents.nix",
    }:
    pkgs.writeShellApplication {
      name = "update-llm-agents";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.nix
      ];
      text = ''
        mkdir -p "$(dirname "${profile}")"
        if test -e "${profile}/manifest.json"; then
          nix profile upgrade --profile "${profile}" --refresh --no-accept-flake-config --all
        else
          nix profile install --profile "${profile}" --no-accept-flake-config \
            "${flake}#codex" \
            "${flake}#claude-code" \
            "${flake}#opencode"
        fi
      '';
    };
}
