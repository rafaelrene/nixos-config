{ inputs, ... }:
{
  flake.modules.darwin.thaw = { pkgs, ... }: {
    environment.systemPackages = [
      # macOS 27 support currently ships on Thaw's alpha channel.
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.thaw.overrideAttrs {
        version = "3.0.0-alpha.7";
        src = pkgs.fetchurl {
          url = "https://github.com/thaw-app/Thaw/releases/download/3.0.0-alpha.7/Thaw_3.0.0-alpha.7.zip";
          hash = "sha256-dANNgipCGnQwQgzb3Ir6LUPhQZ7jZLZO42h9DBqNDfE=";
        };
        dontFixup = true;
      })
    ];
    system.defaults.CustomUserPreferences."com.stonerl.Thaw" = {
      UpdateChannel = "alpha";
      AllowsBetaUpdates = true;
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
  };
}
