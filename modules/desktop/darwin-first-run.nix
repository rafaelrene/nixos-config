{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.desktop-session =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      permission = service: name: client: {
        inherit service name client;
        application = "/Applications/Nix Apps/${name}.app";
      };
      accounts = {
        "Google Drive" = "GoogleDrive-";
        "Proton Drive" = "ProtonDrive-";
        Tailscale = "";
        Filen = "";
      };
      settings = pkgs.writeText "workstation-first-run.json" (
        builtins.toJSON {
          user = config.system.primaryUser;
          home = config.users.users.${config.system.primaryUser}.home;
          unattended = config.system.defaults.loginwindow.autoLoginUser != null;
          remoteDesktop = config.environment.launchDaemons."org.nixos.remote-desktop.plist".enable or false;
          desktopSessionService = config.launchd.user.agents.desktop-session.serviceConfig.Label;
          permissions = [
            {
              name = "skhd";
              service = "Accessibility";
              client = "/private/var/lib/skhd/skhd";
              application = "/var/lib/skhd/skhd";
            }
            {
              name = "Nix activation";
              service = "SystemPolicyAppBundles";
              client = "/private/var/lib/nix-darwin/bin/bash";
              application = "/var/lib/nix-darwin/bin/bash";
            }
            {
              name = "Nix network volumes";
              service = "SystemPolicyNetworkVolumes";
              client = "/private/var/lib/nix-darwin/bin/bash";
              application = "/var/lib/nix-darwin/bin/bash";
            }
            {
              name = "Nix background launch";
              service = "Accessibility";
              client = "/private/var/lib/nix-darwin/bin/bash";
              application = "/var/lib/nix-darwin/bin/bash";
            }
            {
              name = "Nix System Events";
              service = "AppleEvents";
              client = "/private/var/lib/nix-darwin/bin/bash";
              application = "/var/lib/nix-darwin/bin/bash";
              target = "com.apple.systemevents";
            }
            (permission "Accessibility" "OmniWM" "com.barut.OmniWM")
            (permission "ScreenCapture" "OmniWM" "com.barut.OmniWM")
            (permission "Accessibility" "Raycast" "com.raycast.macos")
            (permission "Accessibility" "Thaw" "com.stonerl.Thaw")
            (permission "Accessibility" "TypeWhisper" "com.typewhisper.mac")
            (permission "Microphone" "TypeWhisper" "com.typewhisper.mac")
            (permission "ScreenCapture" "Shottr" "cc.ffitch.shottr")
            (permission "ScreenCapture" "Gifox" "com.gifox.gifox2")
            (permission "ScreenCapture" "OBS" "com.obsproject.obs-studio")
            (permission "Accessibility" "RustDesk" "com.carriez.rustdesk")
            (permission "ScreenCapture" "RustDesk" "com.carriez.rustdesk")
          ];
          accounts = lib.mapAttrsToList (
            name: prefix:
            {
              inherit name prefix;
              application = "/Applications/Nix Apps/${name}.app";
            }
            // lib.optionalAttrs (name == "Filen") {
              mountPoint =
                config.workstation.filen.mountPoint
                  or "${config.users.users.${config.system.primaryUser}.home}/Filen";
            }
          ) accounts;
        }
      );
      setup = features.shell.darwinApplication {
        inherit pkgs;
        name = "workstation-setup";
        text = ''
          exec ${(features.shell.runtimes { inherit pkgs; }).python3} ${./first-run.py} ${settings} "$@"
        '';
      };
    in
    {
      environment.systemPackages = [ setup ];
    };
}
