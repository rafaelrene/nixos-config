{ inputs, lib, ... }:
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
    let
      state = "${profile}-updater";
      source = "path:${inputs.self.outPath}?narHash=${lib.escapeURL inputs.self.narHash}";
      settings = pkgs.writeText "llm-agents-updater.json" (
        builtins.toJSON {
          inherit flake profile;
          staged = "${profile}-staged";
          bundle = "(builtins.getFlake ${builtins.toJSON source}).legacyPackages.${pkgs.stdenv.hostPlatform.system}.llmAgentsForSource";
        }
      );
    in
    pkgs.writeShellApplication {
      name = "update-llm-agents";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        gnused
        nix
        jq
        zsh
        (if stdenv.hostPlatform.isDarwin then flock else util-linux)
      ];
      text = ''
        install -d -m 0700 ${lib.escapeShellArg state}
        exec 9>${lib.escapeShellArg "${state}/update.lock"}
        echo "Agent tools: waiting for any existing update to finish..."
        flock 9
        exec ${pkgs.zsh}/bin/zsh -f ${./update.zsh} ${settings} "$@"
      '';
    };
}
