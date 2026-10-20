{ inputs, ... }:
{
  flake.modules.darwin.slack =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = [
        (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.slack.overrideAttrs {
          dontFixup = true;
        })
      ];
      # Slack requires enforced policy. /Library/Managed Preferences is a cache
      # macOS regenerates; register the policy in Directory Services instead.
      # https://slack.com/help/articles/11906214948755-Manage-desktop-app-configurations
      system.activationScripts.postActivation.text = lib.mkAfter ''
        /usr/bin/dscl . -mcxset ${lib.escapeShellArg "/Users/${config.system.primaryUser}"} com.tinyspeck.slackmacgap AutoUpdate always -bool false || exit 1
        /usr/bin/mcxrefresh -n ${lib.escapeShellArg config.system.primaryUser} || exit 1
        /usr/bin/sudo -H -u ${lib.escapeShellArg config.system.primaryUser} -- /usr/bin/osascript -l JavaScript <<'JXA' || exit 1
        ObjC.import('CoreFoundation');
        const domain = $('com.tinyspeck.slackmacgap');
        const key = $('AutoUpdate');
        const valid = Ref();
        const enabled = $.CFPreferencesGetAppBooleanValue(key, domain, valid);
        if (!$.CFPreferencesAppValueIsForced(key, domain) ||
            !valid[0] || enabled) {
          throw new Error('Slack auto-update policy is not enforced');
        }
        JXA
      '';
    };
}
