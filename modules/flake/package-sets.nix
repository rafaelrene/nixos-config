{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args = {
        pkgs =
          if lib.hasSuffix "-darwin" system then
            import inputs.nixpkgs-darwin { inherit system; }
          else
            inputs.nixpkgs.legacyPackages.${system};
        unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    };
}
