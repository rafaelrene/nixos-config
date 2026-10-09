{ inputs, ... }:
{
  flake.modules.darwin.tailscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      package =
        inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.tailscale-app.overrideAttrs
          (old: {
            dontFixup = true;
            # The installed app path exists only after activation.
            installPhase = old.installPhase + ''
              mkdir -p "$out/bin"
              makeWrapper /usr/bin/env "$out/bin/tailscale" \
                --set TAILSCALE_BE_CLI 1 \
                --add-flag '/Applications/Nix Apps/Tailscale.app/Contents/MacOS/Tailscale'
            '';
          });
    in
    {
      environment.systemPackages = [ package ];
      system = {
        # Keep the standalone app, CLI, and extension on one Nix-managed release.
        defaults.CustomUserPreferences."io.tailscale.ipn.macsys" = {
          SUEnableAutomaticChecks = false;
          SUAutomaticallyUpdate = false;
        };

        # Tailscale requires stopping the old app before replacing its bundle.
        # Activation uses Apple's stable Bash; isolate the copy and recovery trap.
        # https://tailscale.com/docs/integrations/mdm/mac#mdm-based-upgrades
        activationScripts.applications.text = lib.mkMerge [
          (lib.mkBefore ''
            (
              ${builtins.readFile ./update-app.sh}
              tailscale_before_app_copy \
                '${package}/Applications/Tailscale.app' \
                '/Applications/Nix Apps/Tailscale.app' \
                ${lib.escapeShellArg user} ${lib.escapeShellArg home} \
                '${lib.getExe pkgs.jq}' '${pkgs.coreutils}/bin/timeout'
          '')
          (lib.mkAfter ''
              tailscale_after_app_copy
            )
          '')
        ];
      };
    };
}
