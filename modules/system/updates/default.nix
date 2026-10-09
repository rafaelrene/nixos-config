{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.updates =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
    in
    {
      environment.systemPackages = [
        (features.shell.darwinApplication {
          inherit pkgs;
          name = "nix-update-packages";
          runtimeInputs = with pkgs; [
            coreutils
            nix
            zsh
            curl
            jq
            libxml2
            _7zz
            unzip
            libarchive
          ];
          text = ''
            exec ${runtimes.zsh} -f ${./updates.zsh} ${lib.escapeShellArg config.workstation.checkout} ${./update-vendor-sources.zsh} "$@"
          '';
        })
      ];
    };
}
