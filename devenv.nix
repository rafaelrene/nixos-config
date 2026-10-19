{ inputs, ... }:
let
  development =
    inputs.flake-parts.lib.mkFlake
      {
        inherit inputs;
        self.outPath = ./.;
      }
      {
        imports = [
          inputs.flake-parts.flakeModules.modules
          (inputs.import-tree ./modules/development)
        ];
        systems = [ ];
      };
in
{
  imports = [ development.modules.devenv.development ];
}
