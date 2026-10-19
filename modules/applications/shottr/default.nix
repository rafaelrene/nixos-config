{ withSystem, ... }:
{
  flake.modules.darwin.shottr =
    { pkgs, ... }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
    in
    {
      # Shottr has no verified native control for disabling its updater.
      environment.systemPackages = [ unstable.shottr ];
    };
}
