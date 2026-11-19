{ config, ... }:
{
  flake.modules.darwin.webapps = { lib, pkgs, ... }: {
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
}
