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
      packages = {
        t3code-nightly = bundle.server;
        t3code = bundle;
        t3code-desktop = bundle.desktop;
      };
    };
}
