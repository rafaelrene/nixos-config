{ config, ... }:
{
  flake.modules = {
    generic.workstation-options = { lib, ... }: {
      options.workstation = {
        user = lib.mkOption {
          type = lib.types.str;
          description = "User whose workstation applications are managed.";
        };
        checkout = lib.mkOption {
          type = lib.types.str;
          description = "Absolute path to the editable workstation checkout.";
        };
        codeRoot = lib.mkOption {
          type = lib.types.str;
          description = "Default directory for projects.";
        };
      };
    };
    nixos.workstation-options.imports = [
      (config.features.modulesFor "generic").workstation-options
    ];
    darwin.workstation-options.imports = [
      (config.features.modulesFor "generic").workstation-options
    ];
  };
}
