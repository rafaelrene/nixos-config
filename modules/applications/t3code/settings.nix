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
          defaultTheme = "othinus";
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
      inherit server desktop client;
      theme = pkgs.writeText "t3code-workstation-theme.json" themeJSON;
      merge = ". *= load(\"${server}\")";
      desktopMerge = ". *= load(\"${desktop}\")";
    };
}
