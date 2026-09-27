let
  common = { lib, ... }: {
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
in
{
  flake.modules.nixos.workstation = common;
  flake.modules.darwin.workstation = common;
}
