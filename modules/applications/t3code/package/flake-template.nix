{
  description = "Rolling official T3 Code server and desktop";

  inputs = {
    nixpkgs.url = "@nixpkgs@";
    flake-parts = {
      url = "@flakeParts@";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      let
        t3code = config.features.t3code;
      in
      {
        imports = [
          ./package.nix
          ./desktop.nix
        ];
        systems = [ "@system@" ];

        perSystem = { pkgs, ... }: {
          packages = rec {
            t3code-nightly = pkgs.callPackage t3code.serverPackage { };
            t3code-desktop = pkgs.callPackage (
              if pkgs.stdenv.hostPlatform.isDarwin then
                t3code.desktopDarwinPackage
              else
                t3code.desktopLinuxPackage
            ) { };
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
    );
}
