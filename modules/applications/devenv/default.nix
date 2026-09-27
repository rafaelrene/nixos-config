{ inputs, ... }:
let
  common = { pkgs, ... }: { environment.systemPackages = [ pkgs.devenv ]; };
in
{
  flake.modules.nixos.devenv = common;
  flake.modules.darwin.devenv =
    { pkgs, ... }:
    let
      unstable = import inputs.nixpkgs-unstable {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    {
      imports = [ common ];
      # The shell hook and agent wrappers must use the same current Devenv.
      nixpkgs.overlays = [ (_final: _prev: { inherit (unstable) devenv; }) ];
    };
}
