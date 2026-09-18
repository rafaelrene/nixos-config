{ lib, pkgs, ... }:
let
  desktop = pkgs.callPackage ./package.nix { };
  stateDir = "/home/raf/.local/share/t3code/userdata";
in
{
  environment.systemPackages = [
    desktop
    (pkgs.makeDesktopItem {
      name = "t3code";
      desktopName = "T3 Code";
      comment = "Desktop client for the Othinus T3 Code server";
      exec = "${lib.getExe desktop} %U";
      icon = "${../webapps/icons/t3code.png}";
      startupWMClass = "t3code";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/t3code" ];
    })
  ];
  # Seed writable native settings without replacing later client preferences.
  systemd.tmpfiles.rules = [
    "C ${stateDir}/desktop-settings.json 0600 raf raf - ${./desktop-settings.json}"
    "C ${stateDir}/client-settings.json 0600 raf raf - ${./client-settings.json}"
  ];
}
