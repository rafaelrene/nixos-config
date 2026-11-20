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
      agentProfile = "${home}/.local/state/nix/profiles/llm-agents";
      executableSuffix = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "-executables";
      themeJSON = features.t3code.theme { inherit lib pkgs; };
      themeId = (builtins.fromJSON themeJSON).id;
      theme = pkgs.writeText "t3code-workstation-theme.json" themeJSON;
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
          providerInstances = {
            codex = {
              driver = "codex";
              enabled = true;
              config = {
                binaryPath = "${agentProfile}-codex${executableSuffix}/bin/codex";
                homePath = "${home}/.local/share/codex";
              };
            };
            claudeAgent = {
              driver = "claudeAgent";
              enabled = true;
              config = {
                binaryPath = "${agentProfile}-claude-code${executableSuffix}/bin/claude";
                homePath = "${home}/.local/share/claude";
              };
            };
            antigravity = {
              driver = "antigravity";
              enabled = true;
              config.binaryPath = "${agentProfile}-antigravity-cli${executableSuffix}/bin/agy";
            };
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
      merge = ''. *= load("${server}") | del(.providerInstances["codex", "claudeAgent", "antigravity"].config.enabled)'';
      desktopMerge = ". *= load(\"${desktop}\")";
    };
}
