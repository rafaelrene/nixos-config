{
  lib,
  pkgs,
  home,
}:
let
  themeJSON = import ./theme.nix { inherit lib pkgs; };
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
}
