{ inputs, ... }:
{
  flake.modules.darwin.proton-pass =
    { pkgs, ... }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    {
      environment.systemPackages = [
        (unstable.proton-pass.overrideAttrs { dontFixup = true; })
      ];

      # Disable Pass's own "Start at login" item. A separate environment agent
      # cannot guarantee ordering with apps launched during login.
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
