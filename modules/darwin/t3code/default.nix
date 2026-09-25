{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.${config.system.primaryUser}.home;
  base = "${home}/.local/share/t3code";
  profile = "${home}/.local/state/nix/profiles/t3code";
  logs = "${home}/.local/state/nix-darwin";
  initialServer = pkgs.callPackage ./package/package.nix { };
  initialDesktop = pkgs.callPackage ./package/desktop.nix { };
  initial =
    assert initialServer.version == initialDesktop.version;
    pkgs.buildEnv {
      name = "t3code-bootstrap";
      paths = [
        initialServer
        initialDesktop
      ];
    };
  updater = import ./update.nix { inherit lib pkgs home; };
  themeJSON = import ../../services/t3code/theme.nix { inherit lib pkgs; };
  theme = pkgs.writeText "t3code-workstation-theme.json" themeJSON;
  settings = pkgs.writeText "t3code-declared-settings.json" (
    builtins.toJSON {
      continueThreadsAfterServerUpdate = true;
      defaultTheme = "othinus";
      defaultThemeSetAt = builtins.hashString "sha256" themeJSON;
      providers = {
        codex.homePath = "${home}/.local/share/codex";
        claudeAgent.homePath = "${home}/.local/share/claude";
      };
    }
  );
  run = pkgs.writeShellApplication {
    name = "run-t3code";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.yq-go
    ];
    text = ''
      umask 077
      mkdir -p "${base}/userdata/themes" "${home}/code"
      # macOS restores the signed upstream app directly, before launchd's env.
      # Its default home must resolve to the same client-only settings.
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
        cp ${settings} "${base}/userdata/settings.json"
      fi
      # $declared belongs to yq, not the shell.
      # shellcheck disable=SC2016
      yq --inplace --output-format=json \
        'load("${settings}") as $declared | .providers *= $declared.providers | .continueThreadsAfterServerUpdate = $declared.continueThreadsAfterServerUpdate | .defaultTheme = $declared.defaultTheme | .defaultThemeSetAt = $declared.defaultThemeSetAt' \
        "${base}/userdata/settings.json"
      install -m600 ${theme} "${base}/userdata/themes/othinus.json"
      exec "$server" serve --base-dir "${base}" \
        --host 127.0.0.1 --port 3773 --no-browser "${home}/code"
    '';
  };
  updateNow = pkgs.writeShellApplication {
    name = "t3-update-now";
    text = ''
      ${lib.getExe updater}
      /bin/launchctl kickstart -k "gui/$(id -u)/org.nixos.t3code"
    '';
  };
  restart = pkgs.writeShellApplication {
    name = "restart-t3code";
    text = ''
      /bin/launchctl kickstart -k "gui/$(id -u)/org.nixos.t3code"
    '';
  };
  command = pkgs.writeShellApplication {
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
  desktop = pkgs.writeShellApplication {
    name = "t3code-desktop";
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
      client="${profile}/Applications/T3 Code (Nightly).app/Contents/MacOS/T3 Code (Nightly)"
      if ! test -x "$client"; then
        client="${initial}/Applications/T3 Code (Nightly).app/Contents/MacOS/T3 Code (Nightly)"
      fi
      exec "$client" "$@"
    '';
  };
  desktopApp = pkgs.runCommand "t3code-client-launcher" { } ''
    mkdir -p "$out/Applications/T3 Code.app/Contents/MacOS"
    mkdir -p "$out/Applications/T3 Code.app/Contents/Resources"
    ln -s ${lib.getExe desktop} "$out/Applications/T3 Code.app/Contents/MacOS/t3code-desktop"
    ln -s "${initial}/Applications/T3 Code (Nightly).app/Contents/Resources/icon.icns" "$out/Applications/T3 Code.app/Contents/Resources/icon.icns"
    cat > "$out/Applications/T3 Code.app/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleName</key><string>T3 Code</string>
      <key>CFBundleIdentifier</key><string>local.proserpina.t3code-client</string>
      <key>CFBundleExecutable</key><string>t3code-desktop</string>
      <key>CFBundleIconFile</key><string>icon.icns</string>
      <key>CFBundleVersion</key><string>1</string>
      <key>CFBundlePackageType</key><string>APPL</string>
    </dict></plist>
    PLIST
  '';
in
{
  system.activationScripts.preActivation.text = lib.mkBefore ''
    # An existing desktop may still own the port through its embedded server.
    if /usr/sbin/lsof -nP -iTCP:3773 -sTCP:LISTEN >/dev/null 2>&1 \
      && ! /bin/launchctl print "gui/$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})/org.nixos.t3code" >/dev/null 2>&1; then
      echo "Port 3773 is already occupied. Quit the existing T3 Code desktop/server before switching." >&2
      exit 1
    fi
  '';

  environment.systemPackages = [
    command
    desktop
    desktopApp
    updater
    updateNow
  ];
  environment.variables.T3CODE_HOME = base;
  workstation.stateAliases.".local/share/t3code" = ".t3";
  launchd.user.envVariables = {
    T3CODE_HOME = base;
    T3CODE_DISABLE_AUTO_UPDATE = "true";
  };
  launchd.user.agents = {
    t3code = {
      environment = {
        HOME = home;
        PATH = "/nix/var/nix/profiles/system/sw/bin:${home}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        SHELL = lib.getExe pkgs.nushell;
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
      ProgramArguments = [ (lib.getExe restart) ];
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 0;
        }
      ];
    };
  };
}
