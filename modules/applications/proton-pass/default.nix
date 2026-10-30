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
    in
    {
      # Preserve the complete vendor signature. Renaming or wrapping the main
      # executable breaks Electron's hardened-runtime library validation.
      environment.systemPackages = [
        (unstable.proton-pass.overrideAttrs { dontFixup = true; })
      ];

      # Pass still fetches release metadata. Block Squirrel installation for all
      # launch paths and stop pending installers before Pass can quit.
      system.activationScripts.preActivation.text = lib.mkBefore ''
        if [ "''${checkActivation:-0}" != 1 ]; then
          proton_pass_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
          /bin/launchctl disable system/me.proton.pass.electron.ShipIt || exit 1
          /bin/launchctl disable "user/$proton_pass_uid/me.proton.pass.electron.ShipIt" || exit 1
          for domain in system "gui/$proton_pass_uid"; do
            job="$domain/me.proton.pass.electron.ShipIt"
            if /bin/launchctl print "$job" >/dev/null 2>&1; then
              /bin/launchctl bootout "$job" || exit 1
            fi
          done
        fi
      '';

      launchd.user.agents.proton-pass = {
        environment.DISABLE_UPDATE_CHECK = "1";
        serviceConfig = {
          ProgramArguments = [ "/Applications/Nix Apps/Proton Pass.app/Contents/MacOS/Proton Pass" ];
          RunAtLoad = true;
          LimitLoadToSessionType = "Aqua";
        };
      };
    };
}
