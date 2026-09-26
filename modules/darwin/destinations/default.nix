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
in
{
  environment.systemPackages = [ launcher ];
  workstation.links.".config/raycast/extensions/workstation-destinations" = toString extension;
  # `start` registers new local extensions too; `build-refresh` only updates them.
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    ${lib.escapeShellArgs [
      "/usr/bin/sudo"
      "-H"
      "-u"
      config.system.primaryUser
      "/usr/bin/open"
      "-g"
      "-a"
      "/Applications/Nix Apps/Raycast.app"
      "raycast://cli/workstation-destinations/start?cwd=${extension}"
    ]}
  '';
}
