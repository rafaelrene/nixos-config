{
  flake.modules.darwin.updates =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = [
        (pkgs.writeShellApplication {
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
            exec ${lib.getExe pkgs.zsh} -f ${./updates.zsh} ${lib.escapeShellArg config.workstation.checkout} ${./update-vendor-sources.zsh} "$@"
          '';
        })
      ];
    };
}
