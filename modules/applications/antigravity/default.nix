{ lib, ... }:
{
  flake.modules = lib.genAttrs [ "nixos" "darwin" ] (_: {
    antigravity.environment.variables.AGY_CLI_DISABLE_AUTO_UPDATE = "true";
  });
}
