{ config, lib, ... }:
let
  inherit (config) features;
in
{
  options.features.t3code.settings = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Generate T3 Code server settings and their merge expression.";
  };

  config.features.t3code.settings =
    {
      lib,
      pkgs,
      home,
    }:
    let
      themeJSON = features.t3code.theme { inherit lib pkgs; };
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
      inherit server;
      theme = pkgs.writeText "t3code-workstation-theme.json" themeJSON;
      merge = ". *= load(\"${server}\")";
    };
}
