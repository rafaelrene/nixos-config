{
  inputs,
  config,
  lib,
  ...
}:
{
  options.features.coding-agents.update = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build the updater for an independent coding-agent profile.";
  };

  config.features.coding-agents.update =
    {
      pkgs,
      profile,
      hostname,
      flake ? "github:numtide/llm-agents.nix",
    }:
    let
      runtimes = config.features.shell.runtimes { inherit pkgs; };
      githubAuth = config.features.nix.withGithubAuth { inherit pkgs; };
      state = "${profile}-updater";
      source = "path:${inputs.self.outPath}?narHash=${lib.escapeURL inputs.self.narHash}";
      settings = pkgs.writeText "llm-agents-updater.json" (
        builtins.toJSON {
          inherit flake profile source;
          darwin = pkgs.stdenv.hostPlatform.isDarwin;
          output = "${
            if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "nixos"
          }Configurations.${hostname}.config.system.build.llm-agents";
          staged = "${profile}-staged";
        }
      );
    in
    config.features.shell.application {
      inherit pkgs;
      name = "update-llm-agents";
      runtimeInputs = with pkgs; [
        coreutils
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
        exec ${lib.getExe githubAuth} ${runtimes.zsh} -f ${./update.zsh} ${settings} "$@"
      '';
    };
}
