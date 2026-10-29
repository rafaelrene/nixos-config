{ inputs, lib, ... }:
let
  server = builtins.fromJSON (
    builtins.readFile (inputs.t3-server-releases + "/pkgs/t3code/sources.json")
  );
  desktop = (import (inputs.t3-desktop-releases + "/releases.nix")).nightly;
in
{
  options.features.t3code.releaseFor = lib.mkOption {
    type = lib.types.functionTo lib.types.attrs;
    description = "Select matching signed nightly artifacts from maintained, locked metadata.";
  };
  config.features.t3code.releaseFor =
    system:
    # Keep metadata in immutable Git revisions. Live release APIs include mutable
    # counters, whose response hashes cannot be reproduced on another machine.
    assert lib.assertMsg (
      builtins.match "[0-9]+[.][0-9]+[.][0-9]+-nightly[.][0-9.]+" server.version != null
    ) "T3 Code must use a nightly release.";
    assert lib.assertMsg (
      server.version == desktop.version
    ) "T3 Code nightly server and desktop metadata differ; retry after both package sources update.";
    {
      inherit (server) version;
      serverHash = server.platforms.${system}.hash;
      desktopHash = desktop.sources.${system}.hash;
    };
}
