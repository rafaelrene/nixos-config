{ config, withSystem, ... }:
{
  flake.modules.darwin.yaak =
    { pkgs, ... }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
    in
    {
      # First launch creates the settings database. Until then, disable updates in
      # Settings, close Yaak, and rebuild to apply the managed preference.
      imports = [ (config.features.updates.darwinAppSettings "yaak") ];
      environment.systemPackages = [ unstable.yaak ];
    };
}
