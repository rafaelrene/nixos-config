{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.${config.system.primaryUser}.home;
  launcher = import ../../shell/scripts/destinations {
    inherit pkgs home;
    code = "${home}/code";
    hostname = "proserpina";
  };
  extension = import ./package.nix { inherit pkgs; };
  extensionLink = "${home}/.config/raycast/extensions/workstation-destinations";
in
{
  environment.systemPackages = [ launcher ];
  workstation.links.".config/raycast/extensions/workstation-destinations" = toString extension;
  # Capture the target before workstation.links updates it during activation.
  system.activationScripts.preActivation.text = lib.mkAfter ''
    previousRaycastExtension="$(readlink ${lib.escapeShellArg extensionLink} || true)"
  '';
  # `start` opens Raycast; only use it to register the initial installation.
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    if [[ "$previousRaycastExtension" != ${lib.escapeShellArg (toString extension)} ]]; then
      raycastAction=build-refresh
      if [[ -z "$previousRaycastExtension" ]]; then
        raycastAction=start
      fi
      ${
        lib.escapeShellArgs [
          "/usr/bin/sudo"
          "-H"
          "-u"
          config.system.primaryUser
          "/usr/bin/open"
          "-g"
          "-a"
          "/Applications/Nix Apps/Raycast.app"
        ]
      } "raycast://cli/workstation-destinations/$raycastAction?cwd=${extension}"
    fi
  '';
}
