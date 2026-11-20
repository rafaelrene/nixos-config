{
  flake.modules.darwin.desktop-unattended =
    { config, lib, ... }:
    let
      unattended = config.workstation.desktop.sessionPolicy == "unattended";
    in
    {
      options.workstation.desktop.sessionPolicy = lib.mkOption {
        type = lib.types.enum [
          "unattended"
          "manual-lock"
        ];
        default = "manual-lock";
        description = "Use automatic login without locking, or password login with manual locking and no idle lock.";
      };
      config = {
        workstation.desktop.loginUtilities = false;
        system.defaults = {
          loginwindow.autoLoginUser = if unattended then config.system.primaryUser else null;
          screensaver = {
            askForPassword = !unattended;
            askForPasswordDelay = 0;
          };
          CustomSystemPreferences."com.apple.loginwindow" = {
            DisableScreenLockImmediate = unattended;
            autoLogoutDelay = 0;
          };
          CustomUserPreferences = {
            "com.apple.loginwindow" = {
              DisableScreenLockImmediate = unattended;
              TALLogoutSavesState = false;
            };
            NSGlobalDomain = {
              ApplePersistence = false;
              NSQuitAlwaysKeepsWindows = false;
            };
            "com.apple.screensaver" = {
              idleTime = 0;
              askForPassword = if unattended then 0 else 1;
              askForPasswordDelay = 0;
            };
          };
        };
        system.activationScripts.postActivation.text = lib.mkAfter ''
          /usr/bin/dscl . -mcxset /Computers/localhost \
            com.apple.loginwindow DisableScreenLockImmediate always -bool ${lib.boolToString unattended}
          /usr/bin/mcxrefresh -n ${lib.escapeShellArg config.system.primaryUser}
          /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
            /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 0
          /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
            /usr/bin/defaults -currentHost write com.apple.screensaver askForPassword -bool ${lib.boolToString (!unattended)}
          /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
            /usr/bin/defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0
          /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- \
            /usr/bin/defaults -currentHost write com.apple.loginwindow TALLogoutSavesState -bool false
          ${lib.optionalString (!unattended) ''
            if /usr/bin/defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser >/dev/null 2>&1; then
              /usr/bin/defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser
            fi
            /bin/rm -f /etc/kcpassword
          ''}
        '';
      };
    };
}
