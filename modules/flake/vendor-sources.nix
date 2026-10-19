{ lib, ... }:
{
  options.features.vendorSources = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          version = lib.mkOption { type = lib.types.str; };
          url = lib.mkOption { type = lib.types.str; };
          hash = lib.mkOption { type = lib.types.str; };
        };
      }
    );
    default = builtins.fromJSON (builtins.readFile ../system/updates/vendor-sources.json);
    description = "Pinned vendor releases maintained by the system updater.";
  };
}
