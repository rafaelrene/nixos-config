{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    headless.imports =
      (with (config.features.modulesFor platform); [
        workstation-options
        workstation-secrets
        system
        power-management
        fonts
        updates
        development
        filen
        google-drive
        proton-drive
        rex
        tailscale
        truenas
      ])
      ++ lib.optional (platform == "darwin") (config.features.modulesFor "darwin").user-files;
  });
}
