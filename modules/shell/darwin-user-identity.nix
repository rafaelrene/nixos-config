{ config, lib, ... }:
{
  options.features.shell.darwinUserIdentity = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Give a rolling user profile fixed executable paths and a persistent local signing identity.";
  };

  config.features.shell.darwinUserIdentity =
    {
      pkgs,
      package,
      bin,
      state,
      installedApplications ? "${builtins.dirOf bin}/Applications",
      resourceSymlinks ? { },
      resourceTrees ? { },
      resourceFiles ? { },
      resourceExecutableAliases ? { },
    }:
    assert pkgs.stdenv.hostPlatform.isDarwin;
    let
      runtimes = config.features.shell.runtimes { inherit pkgs; };
      externalExecutables = lib.listToAttrs [
        (lib.nameValuePair (builtins.unsafeDiscardStringContext "${pkgs.bashInteractive}/bin/bash") runtimes.bash)
        (lib.nameValuePair (builtins.unsafeDiscardStringContext "${pkgs.bash}/bin/bash") runtimes.bash)
        (lib.nameValuePair (builtins.unsafeDiscardStringContext (lib.getExe pkgs.zsh)) runtimes.zsh)
        (lib.nameValuePair (builtins.unsafeDiscardStringContext (lib.getExe pkgs.python3)) runtimes.python3)
        (lib.nameValuePair (builtins.unsafeDiscardStringContext (lib.getExe pkgs.nodejs_24)) "${runtimes.directory}/node")
      ];
      sources = pkgs.writeText "darwin-user-executable-sources.json" (
        builtins.toJSON {
          inherit bin externalExecutables installedApplications;
          systemBin = "${package}/bin";
          applications = "${package}/Applications";
        }
      );
      payload =
        pkgs.runCommand "darwin-user-executables"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.stdenv.cc
              pkgs.makeBinaryWrapper
              pkgs.darwin.cctools
            ];
          }
          ''
            python3 ${../system/darwin-identity/build-executables.py} ${sources} "$out"
            source "$out/rebuild-wrappers.sh"
          '';
      manifestData = {
        inherit
          bin
          state
          payload
          installedApplications
          resourceSymlinks
          resourceTrees
          resourceFiles
          resourceExecutableAliases
          ;
        applications = "${package}/Applications";
        openssl = lib.getExe pkgs.openssl;
        bootstrapBash = "${pkgs.bashInteractive}/bin/bash";
      };
      manifest = pkgs.writeText "darwin-user-executable-identities.json" (builtins.toJSON manifestData);
      metadata = pkgs.writeTextFile {
        name = "darwin-user-identity-install";
        destination = "/share/darwin-identity/install";
        executable = true;
        text = ''
          #!${runtimes.bash}
          exec ${runtimes.python3} ${../system/darwin-identity/install.py} ${manifest} executables
        '';
      };
    in
    pkgs.buildEnv {
      name = "${package.name}-stable";
      paths = [
        package
        metadata
        (pkgs.writeTextDir "share/darwin-identity/manifest.json" (builtins.toJSON manifestData))
      ];
      passthru = removeAttrs (package.passthru or { }) [ "paths" ] // {
        darwinIdentity = {
          inherit
            bin
            state
            payload
            manifest
            ;
        };
      };
    };
}
