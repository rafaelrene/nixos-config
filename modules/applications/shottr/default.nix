{ config, withSystem, ... }:
let
  desktopSession = (config.features.modulesFor "darwin").desktop-session;
in
{
  flake.modules.darwin.shottr =
    { pkgs, ... }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
    in
    {
      imports = [ desktopSession ];
      workstation.desktop.loginApplications = [ "Shottr" ];
      system.defaults.CustomUserPreferences."cc.ffitch.shottr" = {
        KeyboardShortcuts_area = builtins.toJSON {
          carbonModifiers = 4096;
          carbonKeyCode = 19;
        };
        KeyboardShortcuts_fullscreen = builtins.toJSON {
          carbonModifiers = 4096;
          carbonKeyCode = 18;
        };
        KeyboardShortcuts_ocr = builtins.toJSON {
          carbonModifiers = 4608;
          carbonKeyCode = 31;
        };
      };

      # Shottr has no verified native control for disabling its updater.
      environment.systemPackages = [ unstable.shottr ];
    };
}
