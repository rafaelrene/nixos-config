{ inputs, lib, ... }:
{
  options.features.t3code.updaterSource = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Generate the independent T3 Code updater flake and package modules.";
  };

  config.features.t3code.updaterSource =
    { pkgs }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      flake = pkgs.replaceVars ./flake-template.nix {
        system = pkgs.stdenv.hostPlatform.system;
        flakeParts = "github:hercules-ci/flake-parts/${inputs.flake-parts.rev}";
        nixpkgs =
          if isDarwin then
            "github:NixOS/nixpkgs/nixpkgs-26.05-darwin"
          else
            "github:NixOS/nixpkgs/nixos-26.05";
      };
      desktop = if isDarwin then ./desktop-darwin.nix else ./desktop-linux.nix;
    in
    # Preserve the flat filenames used by nix-update and existing staged profiles.
    pkgs.runCommand "t3code-updater-source" { } ''
      mkdir -p "$out"
      cp ${flake} "$out/flake.nix"
      cp ${./package.nix} "$out/package.nix"
      cp ${desktop} "$out/desktop.nix"
    '';
}
