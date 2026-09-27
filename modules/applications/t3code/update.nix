{ inputs, lib, ... }:
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
      project ? null,
    }:
    let
      darwin = pkgs.stdenv.hostPlatform.isDarwin;
      state = "${home}/.local/state/t3code-bundle-updater";
      source = "path:${inputs.self.outPath}?narHash=${lib.escapeURL inputs.self.narHash}";
      settings = pkgs.writeText "t3code-updater.json" (
        builtins.toJSON {
          inherit project darwin;
          bundle = "(builtins.getFlake ${builtins.toJSON source}).legacyPackages.${pkgs.stdenv.hostPlatform.system}.t3codeForRelease";
          profile = "${home}/.local/state/nix/profiles/t3code";
          base = "${home}/.local/share/t3code";
          restartCommand = if darwin then "/bin/launchctl" else "${pkgs.systemd}/bin/systemctl";
        }
      );
    in
    pkgs.writeShellApplication {
      name = "update-t3code";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        nix
        nushell
        (if darwin then flock else util-linux)
      ];
      text = ''
        # Hold the existing process lock across the entire update, including promotion.
        install -d -m 0700 ${lib.escapeShellArg state}
        exec 9>${lib.escapeShellArg "${state}/update.lock"}
        echo "T3 Code: waiting for any existing update to finish..."
        flock 9
        exec nu --no-config-file ${./update.nu} ${settings} "$@"
      '';
    };
}
