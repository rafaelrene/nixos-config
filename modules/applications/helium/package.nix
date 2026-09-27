{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.helium.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Helium package factory with native platform fixes and shared styling.";
  };
  config.features.helium.package =
    {
      lib,
      pkgs,
    }:
    let
      theme = config.features.theme { inherit lib pkgs; };
      package = inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    if pkgs.stdenv.hostPlatform.isDarwin then
      package.overrideAttrs {
        dontFixup = true; # Preserve the signed Mac bundle.
      }
    else
      package.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          ${lib.optionalString theme.dark ''wrapProgram $out/bin/helium --add-flags "--force-dark-mode"''}
        '';
      });
}
