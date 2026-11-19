{
  flake.modules.darwin.desktop-unattended =
    { config, lib, ... }:
    {
      workstation.desktop.loginUtilities = false;
      power.sleep.display = lib.mkForce "never";
      power.restartAfterPowerFailure = true;
      system.defaults = {
        loginwindow.autoLoginUser = config.system.primaryUser;
        screensaver.askForPassword = false;
        CustomSystemPreferences."com.apple.loginwindow" = {
          DisableScreenLockImmediate = true;
          SleepDisabled = true;
          autoLogoutDelay = 0;
        };
        CustomUserPreferences = {
          "com.apple.loginwindow" = {
            DisableScreenLockImmediate = true;
            TALLogoutSavesState = false;
          };
          NSGlobalDomain = {
            ApplePersistence = false;
            NSQuitAlwaysKeepsWindows = false;
          };
          "com.apple.screensaver" = {
            idleTime = 0;
            askForPassword = 0;
          };
        };
      };
      system.activationScripts.postActivation.text = lib.mkAfter ''
        /usr/bin/pmset -a disablesleep 1
        /usr/bin/dscl . -mcxset /Computers/localhost \
          com.apple.loginwindow DisableScreenLockImmediate always -bool true
        /usr/bin/mcxrefresh -n ${lib.escapeShellArg config.system.primaryUser}
        /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
          /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 0
        /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
          /usr/bin/defaults -currentHost write com.apple.loginwindow TALLogoutSavesState -bool false
      '';
    };
}
