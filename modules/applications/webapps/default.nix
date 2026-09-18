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
}
