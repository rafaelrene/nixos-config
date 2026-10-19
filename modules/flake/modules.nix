{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.modulesFor = lib.mkOption {
    type = lib.types.functionTo (lib.types.lazyAttrsOf lib.types.deferredModule);
    description = "Named modules with stable identities for overlapping bundle imports.";
  };

  config.features.modulesFor =
    class:
    lib.mapAttrs (name: module: {
      # Key the final merged module so all its file contributions are kept once.
      key = "${inputs.self.outPath}#modules.${class}.${name}";
      imports = [ module ];
    }) config.flake.modules.${class};
}
