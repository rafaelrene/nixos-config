{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  rustPkgs = pkgs.extend inputs.rust-overlay.overlays.default;
  rustNightly = rustPkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.minimal);
in
pkgs.neovim.override {
  # Mason's installers need these runtimes, but the shell does not.
  wrapperArgs = [
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [
      pkgs.gcc
      pkgs.go
      pkgs.python3
      rustNightly
    ])
  ];
}
