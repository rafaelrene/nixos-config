{ inputs, pkgs, ... }:
let
  helium =
    inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        postFixup = (old.postFixup or "") + ''
          wrapProgram $out/bin/helium --add-flags "--force-dark-mode"
        '';
      });
in
{
  environment.systemPackages = [ helium ];
  environment.sessionVariables.BROWSER = "helium";
}
