{ config, inputs, ... }:
let
  desktopSession = (config.features.modulesFor "darwin").desktop-session;
in
{
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "none";
      extraSetFlags = [
        "--accept-dns=true"
        "--update-check=false"
      ];
    };

    # Keep the existing LAN rules; allow OpenSSH and T3Code over the tailnet too.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      22
      3773
    ];
  };

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
      unattended = (config.workstation.desktop.sessionPolicy or null) == "unattended";
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
      imports = [ desktopSession ];
      workstation.desktop.backgroundApplications = [ "Tailscale" ];
      launchd.user.agents.login-tailscale.serviceConfig.ProgramArguments = lib.mkIf unattended (
        lib.mkForce [
          "/usr/bin/open"
          "-g"
          "-j"
          "/Applications/Nix Apps/Tailscale.app"
        ]
      );
      environment.systemPackages = [ package ];
      system = {
        # Keep the standalone app, CLI, and extension on one Nix-managed release.
        defaults.CustomUserPreferences."io.tailscale.ipn.macsys" = {
          SUEnableAutomaticChecks = false;
          SUAutomaticallyUpdate = false;
        }
        // lib.optionalAttrs unattended {
          # The native walkthrough saves OnboardingFlow after the user completes it.
          HideDockIcon = true;
          TailscaleStartOnLogin = false;
        };

        # Register the signed installer's notarization ticket before stopping
        # Tailscale and replacing its bundle. The app and extension are assessed
        # again after copying, before the GUI asks macOS to activate the extension.
        # Activation uses the stable Nix Bash; isolate the copy and recovery trap.
        # https://tailscale.com/docs/integrations/mdm/mac#mdm-based-upgrades
        activationScripts.applications.text = lib.mkMerge [
          (lib.mkBefore ''
            (
              ${builtins.readFile ./update-app.sh}
              tailscale_before_app_copy \
                '${package}/Applications/Tailscale.app' \
                '/Applications/Nix Apps/Tailscale.app' \
                ${lib.escapeShellArg user} ${lib.escapeShellArg home} \
                '${lib.getExe pkgs.jq}' '${pkgs.coreutils}/bin/timeout' \
                '${package.src}' \
                '${lib.getExe config.system.build.desktopLoginLauncher}'
          '')
          (lib.mkAfter ''
              tailscale_after_app_copy
            )
          '')
        ];
      };
    };
}
