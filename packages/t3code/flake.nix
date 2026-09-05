{
  description = "Rolling official T3 Code nightly packaged with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux = rec {
      t3code-nightly = nixpkgs.legacyPackages.x86_64-linux.callPackage ./package.nix { };
      default = t3code-nightly;
    };
  };
}
