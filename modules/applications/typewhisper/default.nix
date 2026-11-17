{ inputs, ... }:
{
  flake.modules.darwin.typewhisper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.typewhisper.overrideAttrs {
        # Preserve the upstream app signature for macOS permissions.
        dontFixup = true;
      };
      user = config.system.primaryUser;
    in
    {
      environment.systemPackages = [ package ];

      system.activationScripts.postActivation.text = lib.mkAfter ''
        (
          typewhisper_app='/Applications/Nix Apps/TypeWhisper.app'
          if [[ /run/current-system/Applications/TypeWhisper.app -ef '${package}/Applications/TypeWhisper.app' ]]; then
            exit 0
          fi
          typewhisper_uid=$(/usr/bin/id -u ${lib.escapeShellArg user})
          if ! /usr/bin/pgrep -x -u "$typewhisper_uid" TypeWhisper >/dev/null; then
            exit 0
          fi

          echo 'Restarting TypeWhisper after its Nix package changed...' >&2
          /usr/bin/pkill -TERM -x -u "$typewhisper_uid" TypeWhisper
          for ((typewhisper_wait = 0; typewhisper_wait < 30; typewhisper_wait++)); do
            if ! /usr/bin/pgrep -x -u "$typewhisper_uid" TypeWhisper >/dev/null; then
              break
            fi
            /bin/sleep 1
          done
          if /usr/bin/pgrep -x -u "$typewhisper_uid" TypeWhisper >/dev/null; then
            echo 'TypeWhisper did not quit; reopen it manually to load the update.' >&2
            exit 1
          fi
          /bin/launchctl asuser "$typewhisper_uid" /usr/bin/sudo -H \
            -u ${lib.escapeShellArg user} -- /usr/bin/open -g -a "$typewhisper_app"
        )
      '';

      system.defaults.CustomUserPreferences."com.typewhisper.mac" = {
        selectedEngine = "parakeet";
        selectedLanguage = "auto";
        selectedTask = "transcribe";
        translationEnabled = false;
        "plugin.com.typewhisper.parakeet.enabled" = true;
        "plugin.com.typewhisper.parakeet.selectedModel" = "parakeet-tdt-0.6b-v3";
        "plugin.com.typewhisper.parakeet.selectedVersion" = "v3";
        # Keep dictation ready and leave its result available for manual pasting.
        modelAutoUnloadSeconds = 0;
        preserveClipboard = false;
        SUEnableAutomaticChecks = false;
        SUAutomaticallyUpdate = false;
      };
    };
}
