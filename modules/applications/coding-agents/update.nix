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
      name,
      flake ? "github:numtide/llm-agents.nix",
    }:
    let
      runtimes = config.features.shell.runtimes { inherit pkgs; };
      githubAuth = config.features.nix.withGithubAuth { inherit pkgs; };
      notify = config.features.updates.notify { inherit pkgs; };
      state = "${profile}-updater";
      commandName = "update-${if name == "claude-code" then "claude" else name}";
      title = if name == "claude-code" then "Claude Code" else "Codex";
      source = "path:${inputs.self.outPath}?narHash=${lib.escapeURL inputs.self.narHash}";
      settings = pkgs.writeText "${name}-updater.json" (
        builtins.toJSON {
          inherit
            flake
            profile
            source
            commandName
            ;
          darwin = pkgs.stdenv.hostPlatform.isDarwin;
          output = "${
            if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "nixos"
          }Configurations.${hostname}.config.system.build.${name}";
          staged = "${profile}-staged";
        }
      );
    in
    config.features.shell.application {
      inherit pkgs;
      name = commandName;
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
        echo "${title}: waiting for any existing update to finish..."
        flock 9
        exec ${lib.getExe githubAuth} ${runtimes.zsh} -f ${../../system/updates/report.zsh} \
          ${lib.escapeShellArg title} ${lib.escapeShellArg "${state}/update.log"} ${lib.getExe notify} \
          ${./update.zsh} ${settings} "$@"
      '';
    };
}
