{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../../../themes { inherit lib pkgs; };
in
{
  environment.systemPackages = [
    (inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta.override {
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
    })
  ];
}
