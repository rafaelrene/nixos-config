{ inputs, lib, ... }:
let
  release = builtins.fromJSON (builtins.readFile (inputs.t3-release + "/release.json"));
in
{
  options.features.t3code.releaseFor = lib.mkOption {
    type = lib.types.functionTo lib.types.attrs;
    description = "Select matching nightly artifacts from one official release snapshot.";
  };
  config.features.t3code.releaseFor =
    system:
    # Only the updater contacts GitHub. Evaluation reads versioned artifact hashes.
    assert lib.assertMsg (
      builtins.match "[0-9]+[.][0-9]+[.][0-9]+-nightly[.][0-9.]+" release.version != null
    ) "T3 Code must use a nightly release.";
    { inherit (release) version; } // release.platforms.${system};
}
