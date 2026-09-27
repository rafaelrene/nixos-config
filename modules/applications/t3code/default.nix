{ config, lib, ... }:
let
  inherit (config) features;
in
{
  perSystem =
    { pkgs, system, ... }:
    lib.mkIf (system == "x86_64-linux") {
      packages.t3code-nightly = pkgs.callPackage features.t3code.serverPackage { };
    };
}
