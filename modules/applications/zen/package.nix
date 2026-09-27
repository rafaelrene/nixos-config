{
  config,
  inputs,
  lib,
  ...
}:
{
  options.features.zen.package = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Zen package factory with native platform fixes and shared styling.";
  };
  config.features.zen.package =
    {
      lib,
      pkgs,
    }:
    let
      theme = config.features.theme { inherit lib pkgs; };
      package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta;
    in
    if pkgs.stdenv.hostPlatform.isDarwin then
      package.overrideAttrs (old: {
        # Use nix-darwin's stable app path to keep the browser's install identity.
        installPhase =
          lib.replaceStrings [ "\\$HOME/Applications/Home Manager Apps" ] [ "/Applications/Nix Apps" ]
            old.installPhase;
      })
    else
      package.override {
        extraPolicies.Preferences = {
          "zen.theme.accent-color" = {
            Value = "#${theme.accentColor}";
            Status = "locked";
          };
          "browser.theme.toolbar-theme" = {
            Value = if theme.dark then 0 else 1;
            Status = "locked";
          };
        };
      };
}
