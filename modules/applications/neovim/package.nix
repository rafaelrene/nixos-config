{ inputs, lib, ... }:
{
  options.features.neovim.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Neovim package factory with editor helpers on its private PATH.";
  };
  config.features.neovim.package =
    {
      lib,
      pkgs,
      ...
    }:
    let
      rustPkgs = pkgs.extend inputs.rust-overlay.overlays.default;
      rustNightly = rustPkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.minimal);
    in
    pkgs.neovim.override {
      # Editor helpers and Mason's installer runtimes stay on Neovim's private PATH.
      wrapperArgs = [
        "--suffix"
        "PATH"
        ":"
        (lib.makeBinPath [
          pkgs.gcc
          pkgs.go
          pkgs.lazygit
          pkgs.python3
          pkgs.tree-sitter
          pkgs.viu
          rustNightly
        ])
      ];
    };
}
