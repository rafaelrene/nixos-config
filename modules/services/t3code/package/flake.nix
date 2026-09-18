{
  description = "Rolling official T3 Code nightly packaged with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux = rec {
      t3code-nightly = nixpkgs.legacyPackages.x86_64-linux.callPackage ./package.nix { };
      t3code-desktop = nixpkgs.legacyPackages.x86_64-linux.callPackage ./desktop.nix { };
      default =
        assert t3code-nightly.version == t3code-desktop.version;
        nixpkgs.legacyPackages.x86_64-linux.buildEnv {
          name = "t3code-${t3code-nightly.version}";
          paths = [
            t3code-nightly
            t3code-desktop
          ];
        };
    };
  };
}
