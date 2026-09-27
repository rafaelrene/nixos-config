{ config, ... }:
let
  inherit (config) features;
  common = { lib, pkgs, ... }: {
    environment.systemPackages = [ (features.helium.package { inherit lib pkgs; }) ];
  };
in
{
  flake.modules = {
    nixos.helium =
      { lib, pkgs, ... }:
      let
        theme = features.theme { inherit lib pkgs; };
      in
      {
        imports = [ common ];
        environment = {
          sessionVariables.BROWSER = "helium";
          # The upstream Linux binary reads Chromium's system policy directory.
          etc."chromium/policies/managed/theme.json".text = builtins.toJSON {
            BrowserThemeColor = "#${theme.accentColor}";
          };
        };
        xdg.mime.defaultApplications = {
          "text/html" = "helium.desktop";
          "x-scheme-handler/http" = "helium.desktop";
          "x-scheme-handler/https" = "helium.desktop";
          "x-scheme-handler/about" = "helium.desktop";
          "x-scheme-handler/unknown" = "helium.desktop";
        };
      };
    darwin.helium = common;
  };
}
