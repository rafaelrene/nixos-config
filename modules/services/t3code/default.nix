{
  lib,
  pkgs,
  ...
}:

let
  baseDir = "/home/raf/.local/share/t3code";
  updaterDir = "/home/raf/.local/state/t3code-updater";
  profile = "/home/raf/.local/state/nix/profiles/t3code";

  updaterSource = pkgs.runCommand "t3code-updater-source" { } ''
    mkdir -p "$out"
    cp ${./package/flake.nix} "$out/flake.nix"
    cp ${./package/package.nix} "$out/package.nix"
  '';

  updateT3Code = pkgs.writeShellApplication {
    name = "update-t3code";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      git
      gnused
      jq
      nix
      nix-update
    ];
    text = ''
      export NIX_CONFIG="experimental-features = nix-command flakes
      accept-flake-config = false"

      cd ${lib.escapeShellArg updaterDir}

      if ! test -d .git; then
        git init -q
      fi

      # Nix only sees files tracked by a Git-backed flake. Stage the copied
      # sources before creating or evaluating its lock file.
      git add flake.nix package.nix
      if ! test -e flake.lock; then
        nix flake lock --no-accept-flake-config
        git add flake.lock
      fi

      current=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' package.nix)
      latest=$(curl --fail --silent --show-error --retry 3 \
        https://registry.npmjs.org/t3 \
        | jq -er '."dist-tags".nightly') || latest="$current"

      if test "$latest" != "$current"; then
        echo "Updating T3 Code $current -> $latest"
        if ! nix-update --flake --version "$latest" t3code-nightly; then
          echo "Nightly metadata is not buildable yet; retaining $current" >&2
          git restore package.nix flake.lock
        fi
      fi

      if new=$(nix build --no-link --print-out-paths --no-accept-flake-config .#t3code-nightly); then
        previous=$(readlink -f ${lib.escapeShellArg profile} || true)
        if test "$new" != "$previous"; then
          mkdir -p "$(dirname ${lib.escapeShellArg profile})"
          nix-env --profile ${lib.escapeShellArg profile} --set "$new"
          echo "Staged $("$new/bin/t3" --version)"
        fi
        git add package.nix flake.lock
      elif test -x ${lib.escapeShellArg profile}/bin/t3; then
        echo "Nightly build failed; retaining $("${profile}/bin/t3" --version)" >&2
        git restore package.nix flake.lock
      else
        git restore package.nix flake.lock
        echo "T3 Code has no usable generation" >&2
        exit 1
      fi

      if ! test -e ${lib.escapeShellArg baseDir}/.nixos-config-registered; then
        "${profile}/bin/t3" project add /data/code/nixos-config \
          --base-dir ${lib.escapeShellArg baseDir}
        touch ${lib.escapeShellArg baseDir}/.nixos-config-registered
      fi
    '';
  };

  updateNow = pkgs.writeShellApplication {
    name = "t3-update-now";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      systemctl --user start t3code-update.service
      systemctl --user restart t3code.service
    '';
  };
  t3Command = pkgs.writeShellApplication {
    name = "t3";
    text = ''
      if ! test -x "${profile}/bin/t3"; then
        echo "T3Code is not installed yet. Run: systemctl --user start t3code-bootstrap.service" >&2
        exit 1
      fi

      case "''${1-}" in
        "")
          ${pkgs.systemd}/bin/systemctl --user --no-pager status t3code.service
          echo
          echo "T3 Code is managed by systemd. Open http://localhost:3773 or run 't3 pair'."
          exit 0
          ;;
        start|serve)
          echo "T3 Code is managed by systemd; refusing to start a competing server." >&2
          echo "Use: systemctl --user restart t3code.service" >&2
          exit 2
          ;;
      esac

      exec "${profile}/bin/t3" "$@"
    '';
  };
  runT3Code = pkgs.writeShellApplication {
    name = "run-t3code";
    text = ''
      exec "${profile}/bin/t3" serve \
        --base-dir ${lib.escapeShellArg baseDir} \
        --host 0.0.0.0 \
        --port 3773 \
        --no-browser \
        /data/code
    '';
  };
in
{
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 3773 accept comment "Othinus LAN T3Code"
  '';
  environment.variables.T3CODE_HOME = "$HOME/.local/share/t3code";
  environment.systemPackages = [
    t3Command
    updateNow
  ];

  systemd = {
    user.services = {
      t3code-bootstrap = {
        description = "Install the first T3 Code nightly generation";
        unitConfig.ConditionUser = "raf";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe updateT3Code;
          TimeoutStartSec = "4h";
        };
      };

      t3code-update = {
        description = "Stage the latest T3 Code nightly generation";
        unitConfig.ConditionUser = "raf";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe updateT3Code;
          TimeoutStartSec = "4h";
        };
      };

      t3code = {
        description = "Headless T3 Code server";
        wantedBy = [ "default.target" ];
        requires = [ "t3code-bootstrap.service" ];
        after = [
          "network-online.target"
          "t3code-bootstrap.service"
        ];
        unitConfig = {
          ConditionUser = "raf";
          StartLimitIntervalSec = 0;
        };
        environment = {
          # T3 launches harnesses by name. The system path contains our wrappers,
          # which enter a trusted Devenv project before starting the real agent.
          PATH = lib.mkForce "${
            lib.makeBinPath (
              with pkgs;
              [
                bash
                coreutils
                findutils
                gh
                git
                gnugrep
                gnused
                openssh
                systemd
              ]
            )
          }:/run/current-system/sw/bin";
          # T3's PATH probe emits POSIX shell syntax. Keep Nushell interactive,
          # but give this service a compatible shell for the probe.
          SHELL = "${pkgs.bashInteractive}/bin/bash";
          T3CODE_HOME = baseDir;
          T3CODE_TELEMETRY_ENABLED = "false";
          CODEX_HOME = "/home/raf/.local/share/codex";
          CLAUDE_CONFIG_DIR = "/home/raf/.local/share/claude";
        };
        serviceConfig = {
          ExecStart = lib.getExe runT3Code;
          Restart = "always";
          RestartSec = 3;
          UMask = "0077";
          WorkingDirectory = "/data/code";
        };
      };

      t3code-restart = {
        description = "Activate the staged T3 Code nightly";
        unitConfig.ConditionUser = "raf";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl --user restart t3code.service";
        };
      };
    };

    user.timers = {
      t3code-update = {
        description = "Check for a T3 Code nightly every three hours";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10m";
          OnCalendar = "*-*-* 00/3:00:00";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };

      t3code-restart = {
        description = "Restart T3 Code daily onto its staged generation";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 04:00:00";
          Persistent = true;
        };
      };
    };

    tmpfiles.rules = [
      "d ${baseDir} 0700 raf raf - -"
      "d ${baseDir}/userdata 0700 raf raf - -"
      "d /home/raf/.local/state/nix/profiles 0700 raf raf - -"
      "C ${updaterDir} 0700 raf raf - ${updaterSource}"
      "C ${baseDir}/userdata/settings.json 0600 raf raf - ${./settings.json}"
    ];
  };
}
