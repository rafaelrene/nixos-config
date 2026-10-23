{ config, lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (platform: {
    development.imports =
      (with (config.features.modulesFor platform); [
        acli
        btca
        shell
        coding-agents
        devenv
        forgejo-cli
        gh
        linear-cli
        mongodb-compass
        sentry
        t3code
      ])
      ++ lib.optionals (platform == "darwin") (
        with (config.features.modulesFor "darwin");
        [
          yaak
        ]
      );
  });
}
