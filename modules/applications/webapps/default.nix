{ lib, ... }:
{
  options.features.webapps.skill = lib.mkOption {
    type = lib.types.path;
    default = ./skills/create-web-app;
    description = "Editable web app creation skill shared with coding agents.";
  };

  config.flake.modules.darwin.webapps = { lib, pkgs, ... }: {
    workstation.links =
      let
        apps = builtins.fromJSON (builtins.readFile ./darwin-apps.json);
      in
      lib.mapAttrs' (
        name: url:
        let
          filename = lib.replaceStrings [ "/" ] [ "-" ] name;
        in
        {
          name = ".local/share/raycast/scripts/${filename}";
          value = toString (
            pkgs.writeScript filename ''
              #!/bin/sh
              # @raycast.schemaVersion 1
              # @raycast.title ${name}
              # @raycast.mode silent
              # @raycast.packageName Web Apps

              exec ${
                lib.escapeShellArgs [
                  "/Applications/Nix Apps/Chromium.app/Contents/MacOS/Chromium"
                  "--app=${url}"
                ]
              } "$@"
            ''
          );
        }
      ) apps;
  };
}
