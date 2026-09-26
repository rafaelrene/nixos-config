{
  lib,
  pkgs,
  utils,
  ...
}:

let
  baseDir = "/home/raf/.local/share/t3code";
  settings = import ../../applications/t3code/settings.nix {
    inherit lib pkgs;
    home = "/home/raf";
  };
  profile = "/home/raf/.local/state/nix/profiles/t3code";
  updateT3Code = import ../../applications/t3code/update.nix {
    inherit lib pkgs;
    home = "/home/raf";
    project = "/data/code/nixos-config";
  };

  updateNow = pkgs.writeShellApplication {
    name = "t3-update-now";
    text = ''
      ${lib.getExe updateT3Code}
      echo "T3 Code: restarting the server..."
      ${pkgs.systemd}/bin/systemctl --user restart t3code.service
      echo "T3 Code: server restarted. Reopen the desktop to use the staged client."
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
          }:/run/current-system/sw/bin:/home/raf/.local/bin";
          # SHELL also selects the integrated terminal. Supply PATH above because
          # T3's POSIX login-shell probe can fail with Nushell.
          SHELL = lib.getExe pkgs.nushell;
          T3CODE_HOME = baseDir;
          T3CODE_TELEMETRY_ENABLED = "false";
          CODEX_HOME = "/home/raf/.local/share/codex";
          CLAUDE_CONFIG_DIR = "/home/raf/.local/share/claude";
          # bkt otherwise skips Secret Service when running without a display.
          KEYRING_BACKEND = "secret-service";
          DBUS_SESSION_BUS_ADDRESS = "unix:path=%t/bus";
        };
        serviceConfig = {
          # Published theme files must be regular files: T3 rejects file symlinks.
          ExecStartPre = [
            (utils.escapeSystemdExecArgs [
              "${pkgs.coreutils}/bin/install"
              "-Dm600"
              settings.theme
              "${baseDir}/userdata/themes/othinus.json"
            ])
            (utils.escapeSystemdExecArgs [
              (lib.getExe pkgs.yq-go)
              "--inplace"
              "--output-format=json"
              settings.merge
              "${baseDir}/userdata/settings.json"
            ])
          ];
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
      "C ${baseDir}/userdata/settings.json 0600 raf raf - ${settings.server}"
    ];
  };
}
