{ config, inputs, ... }:
let
  inherit (config) features;
  desktopSession = (config.features.modulesFor "darwin").desktop-session;
in
{
  flake.modules.darwin.proton-drive =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      unattended = (config.workstation.desktop.sessionPolicy or null) == "unattended";
      stopNativeLauncher = ''
        proton_drive_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
        /bin/launchctl disable "user/$proton_drive_uid/ch.protonmail.drive.agent"
        if /bin/launchctl print "gui/$proton_drive_uid" >/dev/null 2>&1; then
          /bin/launchctl disable "gui/$proton_drive_uid/ch.protonmail.drive.agent"
          if /bin/launchctl print "gui/$proton_drive_uid/ch.protonmail.drive.agent" >/dev/null 2>&1; then
            /bin/launchctl bootout "gui/$proton_drive_uid/ch.protonmail.drive.agent"
          fi
        fi
      '';
      launch = features.shell.darwinApplication {
        inherit pkgs;
        name = "start-proton-drive";
        text = ''
          ${lib.getExe config.system.build.desktopLoginLauncher} 'Proton Drive'
          for ((attempt = 0; attempt < 30; attempt++)); do
            if /bin/launchctl print "gui/$(/usr/bin/id -u)/ch.protonmail.drive.agent" >/dev/null 2>&1; then
              break
            fi
            /bin/sleep 0.2
          done
          ${stopNativeLauncher}
        '';
      };
    in
    {
      imports = [ desktopSession ];
      # Proton enables its login helper after sign-in. Reopening the running app shows its status window.
      workstation.desktop.backgroundApplications = lib.optionals (!unattended) [ "Proton Drive" ];
      system.activationScripts.postActivation.text = lib.mkIf (!unattended) (
        lib.mkAfter stopNativeLauncher
      );
      launchd.user.agents = lib.mkIf (!unattended) {
        login-proton-drive.serviceConfig.ProgramArguments = lib.mkForce [ (lib.getExe launch) ];
      };
      environment.systemPackages = [
        (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.proton-drive.overrideAttrs {
          dontFixup = true;
        })
      ];
      # These Sparkle controls are declared but have not been verified in Proton Drive.
      system.defaults.CustomUserPreferences."ch.protonmail.drive" = {
        SUEnableAutomaticChecks = false;
        SUAutomaticallyUpdate = false;
      };
    };
}
