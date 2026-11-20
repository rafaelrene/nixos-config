{ config, ... }:
{
  flake.modules = {
    darwin.webapps = { lib, pkgs, ... }: {
      imports = [ (config.features.modulesFor "darwin").ungoogled-chromium ];
      environment.systemPackages = lib.mapAttrsToList (
        name: url:
        pkgs.runCommand "webapp-${builtins.substring 0 12 (builtins.hashString "sha256" name)}"
          { nativeBuildInputs = [ pkgs.stdenv.cc ]; }
          ''
            app="$out/Applications/${name}.app/Contents"
            mkdir -p "$app/MacOS"
            $CC -Wall -Wextra -Werror \
              -DAPP_URL=${lib.escapeShellArg (builtins.toJSON "--app=${url}")} \
              ${./launcher.c} -o "$app/MacOS/launcher"
            cat > "$app/Info.plist" <<'PLIST'
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
              <key>CFBundleExecutable</key><string>launcher</string>
              <key>CFBundleIdentifier</key><string>org.nixos.webapp.${builtins.hashString "sha256" name}</string>
              <key>CFBundleName</key><string>${lib.escapeXML name}</string>
              <key>CFBundleDisplayName</key><string>${lib.escapeXML name}</string>
              <key>CFBundlePackageType</key><string>APPL</string>
              <key>CFBundleVersion</key><string>1</string>
            </dict></plist>
            PLIST
          ''
      ) (builtins.fromJSON (builtins.readFile ./darwin-apps.json));
    };

    nixos.webapps =
      { lib, pkgs, ... }:
      let
        apps = {
          oryx-zsa-voyager-keyboard-config = {
            name = "Oryx (ZSA Voyager Keyboard Config)";
            url = "https://configure.zsa.io/voyager";
            keywords = [
              "oryx"
              "zsa"
              "voyager"
              "keyboard"
              "config"
            ];
          };
        };

        # Desktop Exec quoting has different escape rules from shell quoting.
        quoteExecArg =
          value:
          "\"${
            lib.replaceStrings [ "\\" "\"" "`" "$" "%" ] [ "\\\\\\\\" "\\\\\"" "\\\\`" "\\\\$" "%%" ] value
          }\"";

        mkWebApp =
          id: app:
          pkgs.makeDesktopItem {
            name = "webapp-${id}";
            desktopName = "${app.name} Webapp";
            exec = "/run/current-system/sw/bin/helium ${quoteExecArg "--app=${app.url}"}";
            icon = if app ? icon then "${app.icon}" else "internet-web-browser";
            keywords = app.keywords or [ ];
            terminal = false;
          };
      in
      {
        environment.systemPackages = lib.mapAttrsToList mkWebApp apps;
      };
  };
}
