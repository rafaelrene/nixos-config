{ config, inputs, ... }:
let
  inherit (config) features;
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      t3pkgs =
        if system == "aarch64-darwin" then import inputs.nixpkgs-darwin { inherit system; } else pkgs;
      bundle = features.t3code.bundle { pkgs = t3pkgs; };
    in
    {
      packages.t3code-nightly = bundle.server;
      packages.t3code = bundle;
      # The updater calls the same recipe with the nightly version and its two hashes.
      legacyPackages.t3codeForRelease =
        release:
        features.t3code.bundle {
          pkgs = t3pkgs;
          inherit release;
        };
    };
}
