{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../../../themes { inherit lib pkgs; };
  helium =
    inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        postFixup = (old.postFixup or "") + ''
          ${lib.optionalString theme.dark ''wrapProgram $out/bin/helium --add-flags "--force-dark-mode"''}
        '';
      });
in
{
  environment = {
    systemPackages = [ helium ];
    sessionVariables.BROWSER = "helium";
    # The upstream Linux binary reads Chromium's system policy directory.
    etc."chromium/policies/managed/theme.json".text = builtins.toJSON {
      BrowserThemeColor = "#${theme.accentColor}";
    };
  };
}
