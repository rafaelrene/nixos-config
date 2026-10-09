{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.t3code =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      home = config.users.users.${config.workstation.user}.home;
      codeRoot = config.workstation.codeRoot;
      base = "${home}/.local/share/t3code";
      profile = "${home}/.local/state/nix/profiles/t3code";
      logs = "${home}/.local/state/nix-darwin";
      state = "${home}/.local/state/t3code-bundle-updater";
      writeApplication = args: features.shell.darwinApplication (args // { inherit pkgs; });
      initial = features.t3code.bundle { inherit pkgs; };
      lifecycle = features.t3code.lifecycle {
        inherit
          lib
          pkgs
          home
          initial
          ;
        desktop = client;
      };
      updater = features.t3code.update {
        inherit
          lib
          pkgs
          home
          lifecycle
          ;
      };
      settings = features.t3code.settings { inherit lib pkgs home; };
      terminalShell = features.t3code.terminalShell { inherit pkgs; };
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
          if ! test -e "$clientSettings"; then printf '{}\n' > "$clientSettings"; fi
          yq --inplace --output-format=json '.localEnvironmentEnabled = false' "$clientSettings"
          server="${profile}/bin/t3"
          if ! test -x "$server"; then server="${initial}/bin/t3"; fi
          if ! test -e "${base}/userdata/settings.json"; then
            cp ${settings.server} "${base}/userdata/settings.json"
          fi
          yq --inplace --output-format=json \
            ${lib.escapeShellArg settings.merge} \
            "${base}/userdata/settings.json"
          install -m600 ${settings.theme} "${base}/userdata/themes/othinus.json"
          mkdir -p "${state}"
          reopen="$(${lib.getExe lifecycle} stop-clients)"
          if [[ "$reopen" == true ]]; then
            /bin/launchctl kickstart "gui/$(id -u)/org.nixos.t3code-reopen"
          fi
          generation="${initial}"
          if test -x "${profile}/bin/t3"; then generation="$(readlink -f "${profile}")"; fi
          printf '{"generation":"%s","pid":%s}\n' "$generation" "$$" > "${state}/running.json.tmp"
          mv "${state}/running.json.tmp" "${state}/running.json"
          exec "$server" serve --base-dir "${base}" \
            --host 127.0.0.1 --port 3773 --no-browser "${codeRoot}"
        '';
      };
      updateNow = writeApplication {
        name = "t3-update-now";
        text = ''
          exec ${lib.getExe updater} --restart
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
      command = writeApplication {
        name = "t3";
        text = ''
          case "''${1-}" in
            "") /bin/launchctl print "gui/$(id -u)/org.nixos.t3code"; exit 0 ;;
            start|serve) echo "T3 Code is managed by launchd. Use t3-update-now to update and restart it." >&2; exit 2 ;;
          esac
          server="${profile}/bin/t3"
          if ! test -x "$server"; then server="${initial}/bin/t3"; fi
          exec "$server" "$@"
        '';
      };
      desktop = writeApplication {
        name = "t3code-desktop";
        text = ''
          exec ${lib.getExe lifecycle} launch "$@"
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
          if ! test -e "$settings"; then printf '{}\n' > "$settings"; fi
          # Keep native client preferences while preventing a second, embedded server.
          yq --inplace --output-format=json '.localEnvironmentEnabled = false' "$settings"
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
      ];
      environment.variables.T3CODE_HOME = base;
      workstation.stateAliases.".local/share/t3code" = ".t3";
      launchd.user.envVariables = {
        T3CODE_HOME = base;
        T3CODE_DISABLE_AUTO_UPDATE = "true";
      };
      launchd.user.agents = {
        t3code-reopen.serviceConfig = {
          ProgramArguments = [
            (lib.getExe lifecycle)
            "reopen"
          ];
          RunAtLoad = false;
          StandardOutPath = "${logs}/t3code-desktop.log";
          StandardErrorPath = "${logs}/t3code-desktop.log";
        };
        t3code = {
          environment = {
            HOME = home;
            PATH = "/nix/var/nix/profiles/system/sw/bin:${home}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
            SHELL = lib.getExe terminalShell;
            T3CODE_HOME = base;
            T3CODE_TELEMETRY_ENABLED = "false";
            CODEX_HOME = "${home}/.local/share/codex";
            CLAUDE_CONFIG_DIR = "${home}/.local/share/claude";
            NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          };
          serviceConfig = {
            ProgramArguments = [ (lib.getExe run) ];
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
            ProgramArguments = [ (lib.getExe updater) ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 300;
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
}
