{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    development.imports =
      (with (config.features.modulesFor platform); [
        shell
        coding-agents
        devenv
        forgejo-cli
        gh
        mongodb-compass
        sentry
        t3code
      ])
      ++ lib.optionals (platform == "darwin") (
        with (config.features.modulesFor "darwin");
        [
          orbstack
          yaak
        ]
      );
  });
}
