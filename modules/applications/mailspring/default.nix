{ withSystem, ... }:
{
  flake.modules.darwin.mailspring =
    { pkgs, ... }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
    in
    {
      # Launch after the environment agent so Squirrel inherits DISABLE_UPDATE_CHECK.
      # Electron's other update checks may remain enabled.
      environment.systemPackages = [ unstable.mailspring ];
    };
}
