{
  description = "Rolling T3 Code server and desktop for Proserpina";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  outputs = { nixpkgs, ... }: {
    packages.aarch64-darwin =
      let
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      in
      rec {
        t3code-nightly = pkgs.callPackage ./package.nix { };
        t3code-desktop = pkgs.callPackage ./desktop.nix { };
        default =
          assert t3code-nightly.version == t3code-desktop.version;
          pkgs.buildEnv {
            name = "t3code-${t3code-nightly.version}";
            paths = [
              t3code-nightly
              t3code-desktop
            ];
          };
      };
  };
}
