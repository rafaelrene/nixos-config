{ config, ... }:
let
  inherit (config) features;
  commands =
    {
      lib,
      writeApplication,
      updater,
      lifecycle,
    }:
    {
      updateNow = writeApplication {
        name = "t3-update-now";
        text = ''
          exec ${lib.getExe updater} --restart
        '';
      };
      desktop = writeApplication {
        name = "t3code-desktop";
        text = ''
          exec ${lib.getExe lifecycle} launch "$@"
        '';
      };
      activate = writeApplication {
        name = "t3-activate";
        text = ''
          exec ${lib.getExe lifecycle} request
        '';
      };
      rollback = writeApplication {
        name = "t3-rollback";
        text = ''
          exec ${lib.getExe lifecycle} request-rollback
        '';
      };
    };
in
{
  perSystem =
    { pkgs, ... }:
    let
      bundle = features.t3code.bundle { inherit pkgs; };
    in
    {
      packages = {
        t3code-nightly = bundle.server;
        t3code = bundle;
        t3code-desktop = bundle.desktop;
      };
    };

  flake.modules = {
    nixos.t3code =
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
        androidSdk = config.system.build.androidSdk;
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
          serverConfiguration = "/etc/systemd/user/t3code.service";
        };
        updateT3Code = features.t3code.update {
          hostname = config.networking.hostName;
          inherit
            lib
            pkgs
            home
            lifecycle
            ;
          project = config.workstation.checkout;
        };

        inherit
          (commands {
            inherit lib lifecycle;
            updater = updateT3Code;
            writeApplication = pkgs.writeShellApplication;
          })
          updateNow
          desktop
          activate
          rollback
          ;

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
            printf '{"generation":"%s","pid":%s,"configuration":"%s"}\n' \
              "$(readlink -f "${profile}")" "$$" "$(readlink -f /etc/systemd/user/t3code.service)" > "${state}/running.json.tmp"
            mv "${state}/running.json.tmp" "${state}/running.json"
            exec "${profile}/bin/t3" serve \
              --base-dir ${lib.escapeShellArg baseDir} \
              --host 0.0.0.0 \
              --port 3773 \
              --no-browser \
              ${lib.escapeShellArg codeRoot}
          '';
        };
        client = pkgs.writeShellApplication {
          name = "t3code-client";
          runtimeInputs = [ pkgs.yq-go ];
          text = ''
            umask 077
            settings="${baseDir}/userdata/desktop-settings.json"
            yq --inplace --output-format=json ${lib.escapeShellArg settings.desktopMerge} "$settings"
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
        imports = [ (features.modulesFor "nixos").android ];
        system.build = {
          t3code = features.t3code.bundle { inherit pkgs profile; };
          t3codeUpdater = updateT3Code;
          t3codeActivator = activate;
        };
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
              # Restarting this required unit would also stop an already running server.
              restartIfChanged = false;
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
                ExecStart = "${lib.getExe updateT3Code} --background";
                TimeoutStartSec = "4h";
              };
            };

            t3code = {
              description = "Headless T3 Code server";
              # ns promotes the release and configuration in one coordinated restart.
              restartIfChanged = false;
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
                      androidSdk
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
                inherit (config.environment.variables) ANDROID_HOME;
                SHELL = lib.getExe pkgs.zsh;
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
                    "${baseDir}/userdata/themes/${settings.themeId}.json"
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
            "C ${baseDir}/userdata/desktop-settings.json 0600 ${user} ${group} - ${settings.desktop}"
            "C ${baseDir}/userdata/client-settings.json 0600 ${user} ${group} - ${settings.client}"
          ];
        };
      };

    darwin.t3code =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        runtimes = features.shell.runtimes { inherit pkgs; };
        home = config.users.users.${config.workstation.user}.home;
        codeRoot = config.workstation.codeRoot;
        base = "${home}/.local/share/t3code";
        profile = "${home}/.local/state/nix/profiles/t3code";
        logs = "${home}/.local/state/nix-darwin";
        state = "${home}/.local/state/t3code-bundle-updater";
        writeApplication = args: features.shell.darwinApplication (args // { inherit pkgs; });
        initial = features.t3code.bundle { inherit pkgs profile; };
        lifecycle = features.t3code.lifecycle {
          inherit
            lib
            pkgs
            home
            initial
            ;
          desktop = client;
          serverConfiguration = lib.getExe run;
        };
        updater = features.t3code.update {
          hostname = config.networking.hostName;
          inherit
            lib
            pkgs
            home
            lifecycle
            ;
        };
        settings = features.t3code.settings { inherit lib pkgs home; };
        run = writeApplication {
          name = "run-t3code";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.yq-go
          ];
          text = ''
            umask 077
            mkdir -p "${base}/userdata/themes" "${codeRoot}"
            # Direct macOS launches must resolve to the same client-only settings.
            if ! test -e "${home}/.t3" && ! test -L "${home}/.t3"; then
              ln -s "${base}" "${home}/.t3"
            fi
            # Dock and URL launches must use the same client state as our launcher.
            /bin/launchctl setenv T3CODE_HOME "${base}"
            /bin/launchctl setenv T3CODE_DISABLE_AUTO_UPDATE true
            clientSettings="${base}/userdata/desktop-settings.json"
            if ! test -e "$clientSettings"; then install -m600 ${settings.desktop} "$clientSettings"; fi
            yq --inplace --output-format=json ${lib.escapeShellArg settings.desktopMerge} "$clientSettings"
            if ! test -e "${base}/userdata/client-settings.json"; then
              install -m600 ${settings.client} "${base}/userdata/client-settings.json"
            fi
            server="${profile}-executables/bin/t3"
            if ! test -x "$server"; then
              echo "T3 Code's stable executable has not been installed." >&2
              exit 1
            fi
            if ! test -e "${base}/userdata/settings.json"; then
              install -m600 ${settings.server} "${base}/userdata/settings.json"
            fi
            yq --inplace --output-format=json \
              ${lib.escapeShellArg settings.merge} \
              "${base}/userdata/settings.json"
            install -m600 ${settings.theme} "${base}/userdata/themes/${settings.themeId}.json"
            mkdir -p "${state}"
            generation="${initial}"
            if test -x "${profile}/bin/t3"; then generation="$(readlink -f "${profile}")"; fi
            printf '{"generation":"%s","pid":%s,"configuration":"%s"}\n' \
              "$generation" "$$" "$(readlink -f "$0")" > "${state}/running.json.tmp"
            mv "${state}/running.json.tmp" "${state}/running.json"
            # Advertise direct LAN and Tailscale routes to both desktop clients.
            exec "$server" serve --base-dir "${base}" \
              --host 0.0.0.0 --port 3773 --no-browser "${codeRoot}"
          '';
        };
        inherit
          (commands {
            inherit
              lib
              writeApplication
              updater
              lifecycle
              ;
          })
          updateNow
          desktop
          activate
          rollback
          ;
        command = writeApplication {
          name = "t3";
          text = ''
            case "''${1-}" in
              "") /bin/launchctl print "gui/$(id -u)/org.nixos.t3code"; exit 0 ;;
              start|serve) echo "T3 Code is managed by launchd. Use t3-update-now to update and restart it." >&2; exit 2 ;;
            esac
            server="${profile}-executables/bin/t3"
            if ! test -x "$server"; then
              echo "T3 Code's stable executable has not been installed." >&2
              exit 1
            fi
            exec "$server" "$@"
          '';
        };
        client = writeApplication {
          name = "t3code-client";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.yq-go
          ];
          text = ''
            umask 077
            mkdir -p "${base}/userdata"
            settings="${base}/userdata/desktop-settings.json"
            if ! test -e "$settings"; then install -m600 ${settings.desktop} "$settings"; fi
            # Keep native client preferences while preventing a second, embedded server.
            yq --inplace --output-format=json ${lib.escapeShellArg settings.desktopMerge} "$settings"
            export T3CODE_HOME="${base}"
            export T3CODE_DISABLE_AUTO_UPDATE=true
            client="${home}/Applications/T3 Code.app"
            /bin/launchctl setenv T3CODE_HOME "${base}"
            /bin/launchctl setenv T3CODE_DISABLE_AUTO_UPDATE true
            # LaunchServices focuses an existing client rather than starting another.
            exec /usr/bin/open -a "$client" \
              --env "T3CODE_HOME=${base}" \
              --env T3CODE_DISABLE_AUTO_UPDATE=true --args "$@"
          '';
        };
      in
      {
        imports = [ (features.modulesFor "darwin").android ];
        system.build = {
          t3code = initial;
          t3codeUpdater = updater;
          t3codeActivator = activate;
        };
        system.activationScripts.preActivation.text = lib.mkBefore ''
          # An existing desktop may still own the port through its embedded server.
          if /usr/sbin/lsof -nP -iTCP:3773 -sTCP:LISTEN >/dev/null 2>&1 \
            && ! /bin/launchctl print "gui/$(/usr/bin/id -u ${lib.escapeShellArg config.workstation.user})/org.nixos.t3code" >/dev/null 2>&1; then
            echo "Port 3773 is already occupied. Quit the existing T3 Code desktop/server before switching." >&2
            exit 1
          fi
        '';

        environment.systemPackages = [
          command
          desktop
          updater
          updateNow
          activate
          rollback
          run
        ];
        environment.variables.T3CODE_HOME = base;
        workstation.stateAliases.".local/share/t3code" = ".t3";
        launchd.user.envVariables = {
          T3CODE_HOME = base;
          T3CODE_DISABLE_AUTO_UPDATE = "true";
        };
        launchd.user.agents = {
          t3code = {
            environment = config.launchd.user.envVariables // {
              inherit (config.environment.variables) ANDROID_HOME;
              HOME = home;
              PATH = "${runtimes.directory}:/nix/var/nix/profiles/system/sw/bin:${home}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
              SHELL = runtimes.zsh;
              T3CODE_HOME = base;
              T3CODE_TELEMETRY_ENABLED = "false";
              CODEX_HOME = "${home}/.local/share/codex";
              CLAUDE_CONFIG_DIR = "${home}/.local/share/claude";
              NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
            };
            serviceConfig = {
              # ns coordinates release and launcher changes after the system switch.
              ProgramArguments = [ "/nix/var/nix/profiles/system/sw/bin/run-t3code" ];
              RunAtLoad = true;
              KeepAlive = true;
              ThrottleInterval = 30;
              Umask = 63;
              StandardOutPath = "${logs}/t3code.log";
              StandardErrorPath = "${logs}/t3code.log";
            };
          };
          t3code-update = {
            environment.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
            serviceConfig = {
              ProgramArguments = [
                (lib.getExe updater)
                "--background"
              ];
              # Switches load jobs before the Nix daemon is ready. Use the schedule.
              RunAtLoad = false;
              StartInterval = 10800;
              ProcessType = "Background";
              StandardOutPath = "${logs}/t3code-update.log";
              StandardErrorPath = "${logs}/t3code-update.log";
            };
          };
          t3code-restart.serviceConfig = {
            ProgramArguments = [
              (lib.getExe lifecycle)
              "activate"
            ];
            StandardOutPath = "${logs}/t3code-activation.log";
            StandardErrorPath = "${logs}/t3code-activation.log";
            StartCalendarInterval = [
              {
                Hour = 4;
                Minute = 0;
              }
            ];
          };
          t3code-rollback.serviceConfig = {
            ProgramArguments = [
              (lib.getExe lifecycle)
              "rollback"
            ];
            StandardOutPath = "${logs}/t3code-activation.log";
            StandardErrorPath = "${logs}/t3code-activation.log";
          };
        };
      };
  };
}
