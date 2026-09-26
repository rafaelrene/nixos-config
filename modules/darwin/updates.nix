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
        nushell
        _7zz
        unzip
        libarchive
      ];
      text = ''
        exec nu --no-config-file ${./updates.nu} ${lib.escapeShellArg config.workstation.checkout} ${./update-vendor-sources.nu} "$@"
      '';
    })
  ];
}
