{ config, inputs, ... }:
let
  desktopSession = (config.features.modulesFor "darwin").desktop-session;
in
{
  flake.modules.darwin.gifox = { pkgs, ... }: {
    imports = [ desktopSession ];
    workstation.desktop.loginApplications = [ "Gifox" ];
    system.defaults.CustomUserPreferences."com.gifox.gifox2" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };

    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.gifox.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
