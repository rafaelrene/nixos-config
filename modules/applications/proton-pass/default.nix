{ withSystem, ... }:
{
  flake.modules.darwin.proton-pass =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
      upstream = unstable.proton-pass.overrideAttrs { dontFixup = true; };
      proton-pass =
        pkgs.runCommand upstream.name
          {
            inherit (upstream) pname version meta;
          }
          ''
            original="${upstream}/Applications/Proton Pass.app/Contents"
            app="$out/Applications/Proton Pass.app/Contents"
            mkdir -p "$app/MacOS"
            for part in "$original"/*; do
              case "''${part##*/}" in
                MacOS|_CodeSignature) continue ;;
              esac
              ln -s "$part" "$app/"
            done
            # Execute through this bundle so Dock and session restoration retain
            # the launcher. The vendor executable and its signature stay intact.
            ln -s "$original/MacOS/Proton Pass" "$app/MacOS/Proton Pass.unwrapped"
            cat > "$app/MacOS/Proton Pass" <<'LAUNCHER'
            #!/bin/sh
            export DISABLE_UPDATE_CHECK=1
            exec "''${0%/*}/Proton Pass.unwrapped" "$@"
            LAUNCHER
            chmod +x "$app/MacOS/Proton Pass"
          '';
    in
    {
      environment.systemPackages = [ proton-pass ];

      # Stop pending Squirrel installers before Pass can quit during activation.
      system.activationScripts.preActivation.text = lib.mkBefore ''
        if [ "''${checkActivation:-0}" != 1 ]; then
          for domain in system "gui/$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})"; do
            job="$domain/me.proton.pass.electron.ShipIt"
            if /bin/launchctl print "$job" >/dev/null 2>&1; then
              /bin/launchctl bootout "$job" || exit 1
            fi
          done
        fi
      '';

      # Squirrel's installer is disabled for every launch; Pass may still fetch
      # release metadata. Keep the login agent for automatic startup only.
      launchd.user.agents.proton-pass = {
        serviceConfig = {
          ProgramArguments = [ "/Applications/Nix Apps/Proton Pass.app/Contents/MacOS/Proton Pass" ];
          RunAtLoad = true;
          LimitLoadToSessionType = "Aqua";
        };
      };
    };
}
