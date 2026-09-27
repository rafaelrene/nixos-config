{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  development =
    inputs.flake-parts.lib.mkFlake
      {
        inherit inputs;
        self.outPath = ./.;
      }
      {
        imports = [
          inputs.flake-parts.flakeModules.modules
        ]
        ++ builtins.filter (path: lib.hasSuffix ".nix" (toString path)) (
          lib.filesystem.listFilesRecursive ./modules/development
        );
        systems = [ ];
      };
in
{
  imports = [ development.modules.devenv.development ];
}
