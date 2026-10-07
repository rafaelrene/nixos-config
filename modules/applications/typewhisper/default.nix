{ inputs, ... }:
{
  flake.modules.darwin.typewhisper = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.typewhisper.overrideAttrs {
        # Preserve the upstream app signature for macOS permissions.
        dontFixup = true;
      })
    ];

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
