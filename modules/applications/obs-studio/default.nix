{ inputs, config, ... }:
{
  flake.modules.nixos.obs-studio = {
    # OBS includes PipeWire window capture, x264, VA-API and NVENC on Linux.
    # The Linux frontend has no built-in application updater; Nix owns updates.
    programs.obs-studio.enable = true;
  };
  flake.modules.darwin.obs-studio = { pkgs, ... }: {
    imports = [
      (config.features.updates.darwinAppSettings {
        process = "OBS";
        directory = "Library/Application Support/obs-studio";
        files."global.ini" = {
          format = "ini";
          settings.General.EnableAutoUpdates = false;
        };
      })
    ];
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.obs.overrideAttrs {
        # Preserve the vendor signature for Screen Recording permission.
        dontFixup = true;
      })
    ];
    system.defaults.CustomUserPreferences."com.obsproject.obs-studio" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
  };
}
