{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    development.imports = with (config.features.modulesFor platform); [
      acli
      android
      btca
      shell
      coding-agents
      devenv
      forgejo-cli
      gh
      linear-cli
      sentry
      t3code
    ];
  });
}
