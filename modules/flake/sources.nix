{ inputs, lib, ... }:
{
  options.features.sources.checkoutPath = lib.mkOption {
    type = lib.types.functionTo lib.types.str;
    description = "Resolve a flake source file to its live path in the editable checkout.";
  };

  config.features.sources.checkoutPath =
    { checkout, source }:
    let
      prefix = "${inputs.self.outPath}/";
      path = toString source;
    in
    assert lib.assertMsg (lib.hasPrefix prefix path) "Editable sources must belong to this flake.";
    "${checkout}/${lib.removePrefix prefix path}";
}
