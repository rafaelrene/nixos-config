{ config, lib, ... }:
let
  inherit (config.features) t3code;
  packaged = builtins.fromJSON (builtins.readFile ./release.json);
in
{
  options.features.t3code.bundle = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build one T3 Code server and desktop generation from release metadata.";
  };

  config.features.t3code.bundle =
    {
      pkgs,
      release ? {
        inherit (packaged) version;
      }
      // packaged.${pkgs.stdenv.hostPlatform.system},
    }:
    let
      server = pkgs.callPackage t3code.serverPackage {
        inherit (release) version;
        hash = release.serverHash;
      };
      desktop =
        pkgs.callPackage
          (
            if pkgs.stdenv.hostPlatform.isDarwin then
              t3code.desktopDarwinPackage
            else
              t3code.desktopLinuxPackage
          )
          {
            inherit (release) version;
            hash = release.desktopHash;
          };
    in
    pkgs.buildEnv {
      name = "t3code-${release.version}";
      passthru = { inherit server desktop; };
      paths = [
        server
        desktop
        # Keep release metadata with the generation, without mutable version state.
        (pkgs.writeTextDir "share/t3code/release.json" (builtins.toJSON release))
      ];
    };
}
