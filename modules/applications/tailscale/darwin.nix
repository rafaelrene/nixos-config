{ inputs, ... }:
{
  flake.modules.darwin.tailscale = { pkgs, ... }: {
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.tailscale-app.overrideAttrs (old: {
        dontFixup = true;
        # The installed app path exists only after activation.
        installPhase = old.installPhase + ''
          mkdir -p "$out/bin"
          makeWrapper /usr/bin/env "$out/bin/tailscale" \
            --set TAILSCALE_BE_CLI 1 \
            --add-flag '/Applications/Nix Apps/Tailscale.app/Contents/MacOS/Tailscale'
        '';
      }))
    ];
    system.defaults.CustomUserPreferences."io.tailscale.ipn.macsys" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
  };
}
