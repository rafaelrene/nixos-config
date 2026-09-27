{ lib, ... }:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
in
{
  options.features.t3code.desktopLinuxPackage = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Package the official Linux T3 Code desktop AppImage.";
  };

  config.features.t3code.desktopLinuxPackage =
    {
      appimageTools,
      fetchurl,
      lib,
      version ? release.version,
      hash ? release.x86_64-linux.desktopHash,
    }:
    appimageTools.wrapType2 rec {
      pname = "t3code-desktop";
      inherit version;
      src = fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
        inherit hash;
      };
      extraPkgs = pkgs: [ pkgs.libsecret ];
      extraBwrapArgs = [
        "--setenv T3CODE_DISABLE_AUTO_UPDATE true"
        # Keep T3Code's generated URL handler pointing at the NixOS wrapper.
        "--setenv APPIMAGE /run/current-system/sw/bin/t3code-desktop"
      ];
      meta = {
        description = "T3 Code desktop client";
        homepage = "https://t3.codes";
        license = lib.licenses.mit;
        mainProgram = "t3code-desktop";
        platforms = [ "x86_64-linux" ];
      };
    };
}
