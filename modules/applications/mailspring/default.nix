{ inputs, ... }:
{
  flake.modules.darwin.mailspring =
    { pkgs, ... }:
    {
      # Launch after the environment agent so Squirrel inherits DISABLE_UPDATE_CHECK.
      # Electron's other update checks may remain enabled.
      environment.systemPackages = [
        (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.mailspring.overrideAttrs {
          dontFixup = true;
        })
      ];
    };
}
