{ inputs, ... }:
let
  common =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.devenv ];
      # Patch the package used by the shell hook and agent wrappers as well.
      nixpkgs.overlays = [
        (
          _final: prev:
          let
            source =
              if prev.stdenv.hostPlatform.isDarwin then
                import inputs.nixpkgs-unstable {
                  system = prev.stdenv.hostPlatform.system;
                  config.allowUnfree = true;
                }
              else
                prev;
          in
          {
            devenv = source.devenv.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./nushell-reload-path.patch ];
            });
          }
        )
      ];
    };
in
{
  flake.modules.nixos.devenv = common;
  flake.modules.darwin.devenv = common;
}
