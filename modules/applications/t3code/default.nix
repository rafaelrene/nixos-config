{ config, ... }:
let
  inherit (config) features;
in
{
  perSystem =
    { pkgs, ... }:
    let
      bundle = features.t3code.bundle { inherit pkgs; };
    in
    {
      packages.t3code-nightly = bundle.server;
      packages.t3code = bundle;
      # The updater calls the same recipe with the nightly version and its two hashes.
      legacyPackages.t3codeForRelease =
        release:
        features.t3code.bundle {
          inherit pkgs release;
        };
    };
}
