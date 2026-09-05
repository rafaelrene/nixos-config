{
  description = "Declarative NixOS configuration for Othinus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      mkOthinus =
        extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/othinus/configuration.nix ] ++ extraModules;
        };
    in
    {
      packages.${system}.t3code-nightly =
        nixpkgs.legacyPackages.${system}.callPackage ./packages/t3code/package.nix
          { };

      nixosConfigurations = {
        # The only purpose of this generation is to create a temporary SSH
        # administrator before UID 1000 is renamed from othinus to raf.
        othinus-bootstrap = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./hosts/othinus/bootstrap.nix ];
        };

        # Keep the temporary administrator available while the final desktop is
        # verified under raf. The normal configuration below removes it.
        othinus-migration = mkOthinus [ ./modules/migration-admin.nix ];
        othinus = mkOthinus [ ];
      };
    };
}
