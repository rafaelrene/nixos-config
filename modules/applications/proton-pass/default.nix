{ withSystem, ... }:
{
  flake.modules.darwin.proton-pass =
    { pkgs, ... }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
    in
    {
      environment.systemPackages = [
        (unstable.proton-pass.overrideAttrs { dontFixup = true; })
      ];

      # Pass still checks release metadata. Disable its "Start at login", macOS
      # login item and session restoration so this agent supplies its environment.
      # Stop an existing helper before quitting Pass:
      # sudo launchctl bootout system/me.proton.pass.electron.ShipIt
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
