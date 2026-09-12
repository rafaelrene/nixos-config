{ lib, pkgs, ... }:
let
  apps = {
    t3code-othinus = {
      name = "T3Code (Othinus)";
      url = "http://othinus.local:3773";
      icon = ./icons/t3code.png;
      keywords = [
        "t3"
        "t3code"
        "othinus"
        "coding"
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
