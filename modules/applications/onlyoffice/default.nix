{ inputs, ... }:
{
  flake.modules.darwin.onlyoffice = { pkgs, ... }: {
    system.defaults.CustomUserPreferences."asc.onlyoffice.ONLYOFFICE" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.onlyoffice.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
