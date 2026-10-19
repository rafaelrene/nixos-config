{ withSystem, ... }:
{
  flake.modules.darwin.orbstack =
    { pkgs, ... }:
    let
      unstable = withSystem pkgs.stdenv.hostPlatform.system ({ unstable, ... }: unstable);
    in
    {
      # OrbStack has no verified native control for disabling its updater.
      environment.systemPackages = [ unstable.orbstack ];
    };
}
