{ config, lib, ... }:
{
  options.features.t3code.lifecycle = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Coordinate T3 Code release promotion, server activation and desktop launches.";
  };

  config.features.t3code.lifecycle =
    {
      lib,
      pkgs,
      home,
      desktop,
      initial ? null,
    }:
    let
      darwin = pkgs.stdenv.hostPlatform.isDarwin;
      writeApplication =
        args:
        if darwin then
          config.features.shell.darwinApplication (args // { inherit pkgs; })
        else
          pkgs.writeShellApplication args;
      state = "${home}/.local/state/t3code-bundle-updater";
      desktopSupport = writeApplication {
        name = "t3code-darwin-app";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec python3 ${./darwin-app.py} "$@"
        '';
      };
      notify = writeApplication {
        name = "notify-t3code-error";
        text =
          if darwin then
            ''
              exec /usr/bin/osascript ${./notify.applescript} "$@"
            ''
          else
            ''
              exec ${pkgs.libnotify}/bin/notify-send "T3 Code" "$@"
            '';
      };
      spawn = writeApplication {
        name = "spawn-t3code-client";
        text =
          if darwin then
            ''
              # The client launcher uses LaunchServices, which owns the app's lifetime.
              exec ${lib.getExe desktop} "$@" >>${lib.escapeShellArg "${state}/desktop.log"} 2>&1 </dev/null
            ''
          else
            ''
              # The desktop must outlive the requesting terminal or activation unit.
              exec ${pkgs.systemd}/bin/systemd-run --user --collect --quiet --service-type=exec \
                --property=${lib.escapeShellArg "StandardOutput=append:${state}/desktop.log"} \
                --property=${lib.escapeShellArg "StandardError=append:${state}/desktop.log"} \
                ${lib.getExe desktop} "$@"
            '';
      };
      settings = pkgs.writeText "t3code-lifecycle.json" (
        builtins.toJSON {
          inherit home darwin state;
          initial = if initial == null then null else toString initial;
          profile = "${home}/.local/state/nix/profiles/t3code";
          staged = "${home}/.local/state/nix/profiles/t3code-staged";
          previous = "${home}/.local/state/nix/profiles/t3code-previous";
          desktopApp = "${home}/Applications/T3 Code.app";
          desktopCommand = if darwin then lib.getExe desktopSupport else null;
          spawn = lib.getExe spawn;
          notifyCommand = lib.getExe notify;
          processCommand = if darwin then "/bin/ps" else "${pkgs.procps}/bin/ps";
          serviceCommand = if darwin then "/bin/launchctl" else "${pkgs.systemd}/bin/systemctl";
          serviceFile = "${home}/Library/LaunchAgents/org.nixos.t3code.plist";
          healthUrl = "http://127.0.0.1:3773/.well-known/t3/environment";
        }
      );
    in
    writeApplication {
      name = "t3-lifecycle";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        lsof
        nix
        jq
        zsh
        (if darwin then flock else util-linux)
      ];
      text = ''
        install -d -m 0700 ${lib.escapeShellArg state}
        # Server startup closes clients while activation holds the lock and waits
        # for that server. Requests also wait for the independent coordinator.
        if [[ "''${1-}" == request || "''${1-}" == request-rollback || "''${1-}" == stop-clients ]]; then
          exec ${pkgs.zsh}/bin/zsh -f ${./lifecycle.zsh} ${settings} "$@"
        fi
        if [[ "''${1-}" == reopen ]]; then
          ${pkgs.zsh}/bin/zsh -f ${./lifecycle.zsh} ${settings} ready
          set -- launch
        fi
        # The child does not inherit the lock descriptor, including detached clients.
        exec flock --close ${lib.escapeShellArg "${state}/activation.lock"} \
          ${pkgs.zsh}/bin/zsh -f ${./lifecycle.zsh} ${settings} "$@"
      '';
    };
}
