{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.nixos.t3code =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:

    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
      terminalShell = features.t3code.terminalShell { inherit pkgs; };
      browserLibraries = with pkgs; [
        alsa-lib
        at-spi2-core
        dbus
        expat
        glib
        libgbm
        libxkbcommon
        nspr
        nss
        systemd
        libX11
        libXcomposite
        libXdamage
        libXext
        libXfixes
        libXrandr
        libxcb
      ];
      codeRoot = config.workstation.codeRoot;
      baseDir = "${home}/.local/share/t3code";
      settings = features.t3code.settings {
        inherit lib pkgs home;
      };
      profile = "${home}/.local/state/nix/profiles/t3code";
      state = "${home}/.local/state/t3code-bundle-updater";
      lifecycle = features.t3code.lifecycle {
        inherit lib pkgs home;
        desktop = client;
      };
      updateT3Code = features.t3code.update {
        inherit
          lib
          pkgs
          home
          lifecycle
          ;
        project = config.workstation.checkout;
      };

      updateNow = pkgs.writeShellApplication {
        name = "t3-update-now";
        text = ''
          exec ${lib.getExe updateT3Code} --restart
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
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          umask 077
          mkdir -p "${state}"
          printf '{"generation":"%s","pid":%s}\n' "$(readlink -f "${profile}")" "$$" > "${state}/running.json.tmp"
          mv "${state}/running.json.tmp" "${state}/running.json"
          exec "${profile}/bin/t3" serve \
            --base-dir ${lib.escapeShellArg baseDir} \
            --host 0.0.0.0 \
            --port 3773 \
            --no-browser \
            ${lib.escapeShellArg codeRoot}
        '';
      };
      desktop = pkgs.writeShellApplication {
        name = "t3code-desktop";
        text = ''
          exec ${lib.getExe lifecycle} launch "$@"
        '';
      };
      activate = pkgs.writeShellApplication {
        name = "t3-activate";
        text = ''
          exec ${lib.getExe lifecycle} request
        '';
      };
      rollback = pkgs.writeShellApplication {
        name = "t3-rollback";
        text = ''
          exec ${lib.getExe lifecycle} request-rollback
        '';
      };
      client = pkgs.writeShellApplication {
        name = "t3code-client";
        runtimeInputs = [ pkgs.yq-go ];
        text = ''
          umask 077
          settings="${baseDir}/userdata/desktop-settings.json"
          yq --inplace --output-format=json '.localEnvironmentEnabled = false' "$settings"
          export T3CODE_HOME="${baseDir}"
          export T3CODE_DISABLE_AUTO_UPDATE=true
          client="${profile}/bin/t3code-desktop"
          if ! test -x "$client"; then
            echo "T3 Code desktop is not installed yet. Run: t3-update-now" >&2
            exit 1
          fi
          exec "$client" "$@"
        '';
      };
    in
    {
      environment.variables.T3CODE_HOME = "$HOME/.local/share/t3code";
      environment.systemPackages = [
        t3Command
        updateT3Code
        updateNow
        desktop
        activate
        rollback
        (pkgs.makeDesktopItem {
          name = "t3code";
          desktopName = "T3 Code";
          comment = "Desktop client for the managed T3 Code server";
          exec = "${lib.getExe desktop} %U";
          icon = "${../webapps/icons/t3code.png}";
          startupWMClass = "t3code";
          categories = [ "Development" ];
          mimeTypes = [ "x-scheme-handler/t3code" ];
        })
      ];

      systemd = {
        user.services = {
          t3code-bootstrap = {
            description = "Install the first T3 Code nightly generation";
            unitConfig = {
              ConditionUser = user;
              # Avoid acquiring the download lock while activation waits for startup.
              ConditionPathExists = "!${profile}/bin/t3";
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${lib.getExe updateT3Code} --bootstrap";
              TimeoutStartSec = "4h";
            };
          };

          t3code-update = {
            description = "Stage the latest T3 Code nightly generation";
            unitConfig.ConditionUser = user;
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
              ConditionUser = user;
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
              }:/run/current-system/sw/bin:${home}/.local/bin";
              # Keep the terminal shell and its startup configuration private to T3.
              SHELL = lib.getExe terminalShell;
              # Keep browser libraries private to T3 and its ldd diagnostics.
              LD_LIBRARY_PATH = lib.makeLibraryPath browserLibraries;
              T3CODE_HOME = baseDir;
              T3CODE_TELEMETRY_ENABLED = "false";
              CODEX_HOME = "${home}/.local/share/codex";
              CLAUDE_CONFIG_DIR = "${home}/.local/share/claude";
              # bkt otherwise skips Secret Service when running without a display.
              KEYRING_BACKEND = "secret-service";
              DBUS_SESSION_BUS_ADDRESS = "unix:path=%t/bus";
            };
            serviceConfig = {
              EnvironmentFile = "-${baseDir}/bitbucket.env";
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
              WorkingDirectory = codeRoot;
            };
          };

          t3code-restart = {
            description = "Activate the matching T3 Code server and desktop";
            unitConfig.ConditionUser = user;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe lifecycle} activate";
              TimeoutStartSec = "5min";
            };
          };
          t3code-rollback = {
            description = "Restore the previous matching T3 Code server and desktop";
            unitConfig.ConditionUser = user;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe lifecycle} rollback";
              TimeoutStartSec = "5min";
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
          "d ${baseDir} 0700 ${user} ${group} - -"
          "d ${baseDir}/userdata 0700 ${user} ${group} - -"
          "d ${home}/.local/state/nix/profiles 0700 ${user} ${group} - -"
          "C ${baseDir}/userdata/settings.json 0600 ${user} ${group} - ${settings.server}"
          # Seed writable native settings without replacing later client preferences.
          "C ${baseDir}/userdata/desktop-settings.json 0600 ${user} ${group} - ${./desktop-settings.json}"
          "C ${baseDir}/userdata/client-settings.json 0600 ${user} ${group} - ${./client-settings.json}"
        ];
      };
    };
}
