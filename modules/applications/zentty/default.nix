{ inputs, ... }:
{
  flake.modules.darwin.zentty = { pkgs, ... }: {
    system.defaults.CustomUserPreferences."be.zenjoy.zentty" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.zentty.overrideAttrs (old: {
        dontFixup = true;
        installPhase = old.installPhase + ''
          rm -f "$out/bin/zentty"
          ln -s "$out/Applications/Zentty.app/Contents/Resources/bin/shared/zentty" "$out/bin/zentty"
        '';
      }))
    ];
  };
}
