{ lib, ... }:
let
  android =
    { pkgs, ... }:
    let
      packages = pkgs.androidenv.composeAndroidPackages {
        toolsVersion = null;
        platformVersions = [ "36" ];
        includeEmulator = true;
        includeSystemImages = true;
        systemImageTypes = [ "google_apis" ];
        abiVersions = [ (if pkgs.stdenv.hostPlatform.isDarwin then "arm64-v8a" else "x86_64") ];
        includeCmake = false;
      };
      sdk = packages.androidsdk.overrideAttrs (previous: {
        # T3 Code and Expo look for the unversioned command-line tools path.
        postInstall = (previous.postInstall or "") + ''
          ln -s "$out/libexec/android-sdk/${packages.cmdline-tools-package.path}" \
            "$out/libexec/android-sdk/cmdline-tools/latest"
        '';
      });
    in
    {
      nixpkgs.config.android_sdk.accept_license = true;
      system.build.androidSdk = sdk;
      environment = {
        systemPackages = [ sdk ];
        variables.ANDROID_HOME = "${sdk}/libexec/android-sdk";
      };
    };
in
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (_: {
    inherit android;
  });
}
