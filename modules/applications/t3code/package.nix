{
  appimageTools,
  fetchurl,
  lib,
}:
appimageTools.wrapType2 {
  pname = "t3code-desktop";
  version = "0.0.43-nightly.20260918.1895";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v0.0.43-nightly.20260918.1895/T3-Code-0.0.43-nightly.20260918.1895-x86_64.AppImage";
    hash = "sha256-h73VlZInR+4c9ywQN54czs/t1FGYX/T+SbEKViAds3k=";
  };
  extraPkgs = pkgs: [ pkgs.libsecret ];
  extraBwrapArgs = [
    "--setenv T3CODE_HOME /home/raf/.local/share/t3code"
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
}
