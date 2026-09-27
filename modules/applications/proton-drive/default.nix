{ inputs, ... }:
{
  flake.modules.darwin.proton-drive = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.proton-drive.overrideAttrs {
        dontFixup = true;
      })
    ];
    system.defaults.CustomUserPreferences."ch.protonmail.drive" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
  };
}
