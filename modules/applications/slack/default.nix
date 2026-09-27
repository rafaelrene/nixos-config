{ inputs, ... }:
{
  flake.modules.darwin.slack = { lib, pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.slack.overrideAttrs {
        dontFixup = true;
      })
    ];
    # Slack checks enforced policy; an ordinary user preference is ignored.
    # nix-darwin inserts custom domains into shell commands without quoting.
    system.defaults.CustomSystemPreferences.${lib.escapeShellArg "/Library/Managed Preferences/com.tinyspeck.slackmacgap"}.AutoUpdate =
      false;
  };
}
