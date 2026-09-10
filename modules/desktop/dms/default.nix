{
  config,
  lib,
  pkgs,
  ...
}:
let
  enableBarAutoHide = pkgs.writeShellApplication {
    name = "dms-enable-bar-auto-hide";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # The notification bus can be ready before DMS's IPC endpoint.
      for attempt in {1..10}; do
        response=$(timeout 2s ${lib.getExe config.programs.dms-shell.package} ipc call bar autoHide id default 2>&1) || response="IPC unavailable: $response"
        if [[ "$response" == "BAR_AUTO_HIDE_SUCCESS" ]]; then
          exit 0
        fi
        if (( attempt < 10 )); then
          sleep 1
        fi
      done
      echo "Could not enable DMS bar auto-hide: $response" >&2
      exit 1
    '';
  };
  theme = import ../../../themes { inherit lib pkgs; };
  tokens = {
    inherit (theme) name;
    accent = "#${theme.accentColor}";
  }
  // lib.mapAttrs (_: color: "#${color}") theme.colors;
  dmsTheme = pkgs.writeText "dms-theme.json" (
    lib.replaceStrings (map (name: "@${name}@") (
      builtins.attrNames tokens
    )) (builtins.attrValues tokens) (builtins.readFile ./theme.json)
  );
  defaults = builtins.fromJSON (builtins.readFile ./default-settings.json);
  dmsSettings = pkgs.writeText "dms-default-settings.json" (
    builtins.toJSON (
      defaults
      // {
        fontFamily = theme.font.interface;
        monoFontFamily = theme.font.monospace;
      }
    )
  );
in
{
  programs.dms-shell.enable = true;
  # Log hook failures without restarting the desktop shell.
  systemd.user.services.dms.serviceConfig.ExecStartPost = [
    "-${lib.getExe enableBarAutoHide}"
  ];
  systemd.tmpfiles.rules = [
    "d /home/raf/.config/DankMaterialShell 0700 raf raf - -"
    "L+ /home/raf/.config/DankMaterialShell/theme.json - - - - ${dmsTheme}"
    "C /home/raf/.config/DankMaterialShell/settings.json 0600 raf raf - ${dmsSettings}"
  ];
}
