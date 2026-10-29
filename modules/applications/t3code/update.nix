{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.t3code.update = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build the updater for the matching T3 Code server and desktop.";
  };

  config.features.t3code.update =
    {
      lib,
      pkgs,
      home,
      hostname,
      lifecycle,
      project ? null,
    }:
    let
      runtimes = config.features.shell.runtimes { inherit pkgs; };
      githubAuth = config.features.nix.withGithubAuth { inherit pkgs; };
      notify = config.features.updates.notify { inherit pkgs; };
      darwin = pkgs.stdenv.hostPlatform.isDarwin;
      state = "${home}/.local/state/t3code-bundle-updater";
      resolver = config.features.shell.application {
        inherit pkgs;
        name = "resolve-t3-release";
        runtimeInputs = [ pkgs.gh ];
        text = ''
          exec ${runtimes.python3} ${./resolve-release.py} "$@"
        '';
      };
      source = "path:${inputs.self.outPath}?narHash=${lib.escapeURL inputs.self.narHash}";
      settings = pkgs.writeText "t3code-updater.json" (
        builtins.toJSON {
          inherit project darwin source;
          output = "${
            if darwin then "darwin" else "nixos"
          }Configurations.${hostname}.config.system.build.t3code";
          releaseDirectory = "modules/applications/t3code/release";
          resolverCommand = lib.getExe resolver;
          inherit state;
          profile = "${home}/.local/state/nix/profiles/t3code";
          staged = "${home}/.local/state/nix/profiles/t3code-staged";
          base = "${home}/.local/share/t3code";
          lifecycle = lib.getExe lifecycle;
        }
      );
    in
    config.features.shell.application {
      inherit pkgs;
      name = "update-t3code";
      runtimeInputs = with pkgs; [
        coreutils
        nix
        jq
        zsh
        (if darwin then flock else util-linux)
      ];
      text = ''
        # Hold the existing process lock across the entire update, including promotion.
        install -d -m 0700 ${lib.escapeShellArg state}
        exec 9>${lib.escapeShellArg "${state}/update.lock"}
        echo "T3 Code: waiting for any existing update to finish..."
        flock 9
        exec ${lib.getExe githubAuth} ${runtimes.zsh} -f ${../../system/updates/report.zsh} \
          'T3 Code update' ${lib.escapeShellArg "${state}/update.log"} ${lib.getExe notify} \
          ${./update.zsh} ${settings} "$@"
      '';
    };
}
