{ config, lib, ... }:
let
  inherit (config) features;
in
{
  options.features.t3code.settings = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Generate shared T3 Code native settings and their merge expressions.";
  };

  config.features.t3code.settings =
    {
      lib,
      pkgs,
      home,
    }:
    let
      themeJSON = features.t3code.theme { inherit lib pkgs; };
      themeId = (builtins.fromJSON themeJSON).id;
      theme = pkgs.writeText "t3code-workstation-theme.json" themeJSON;
      python = pkgs.python3.withPackages (ps: [ ps.plyvel ]);
      desktopProfile = "${home}/${
        if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config"
      }/t3code-v2/Local Storage/leveldb";
      desktop = pkgs.writeText "t3code-desktop-settings.json" (
        builtins.toJSON {
          # Both native clients connect to the separately managed server.
          localEnvironmentEnabled = false;
        }
      );
      client = pkgs.writeText "t3code-client-settings.json" (
        builtins.toJSON {
          notificationMode = "notifications-and-sound";
        }
      );
      server = pkgs.writeText "t3code-declared-settings.json" (
        builtins.toJSON {
          continueThreadsAfterServerUpdate = true;
          defaultTheme = themeId;
          # Reapply the selection when the palette changes, not every restart.
          defaultThemeSetAt = builtins.hashString "sha256" themeJSON;
          providers = {
            codex.homePath = "${home}/.local/share/codex";
            claudeAgent.homePath = "${home}/.local/share/claude";
          };
        }
      );
    in
    {
      inherit
        server
        desktop
        client
        themeId
        theme
        ;
      syncTheme = features.shell.application {
        inherit pkgs;
        name = "t3code-sync-theme";
        text = ''
          exec ${python}/bin/python3 ${./sync-theme.py} ${theme} ${lib.escapeShellArg desktopProfile}
        '';
      };
      merge = ". *= load(\"${server}\")";
      desktopMerge = ". *= load(\"${desktop}\")";
    };
}
