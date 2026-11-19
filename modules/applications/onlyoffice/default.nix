{ config, inputs, ... }:
{
  flake.modules.darwin.onlyoffice = { pkgs, ... }: {
    imports = [ (config.features.modulesFor "darwin").desktop-session ];
    workstation.desktop.defaultApplications = ''
      asc.onlyoffice.ONLYOFFICE com.microsoft.word.doc all
      asc.onlyoffice.ONLYOFFICE org.openxmlformats.wordprocessingml.document all
      asc.onlyoffice.ONLYOFFICE com.microsoft.excel.xls all
      asc.onlyoffice.ONLYOFFICE org.openxmlformats.spreadsheetml.sheet all
      asc.onlyoffice.ONLYOFFICE com.microsoft.powerpoint.ppt all
      asc.onlyoffice.ONLYOFFICE org.openxmlformats.presentationml.presentation all
      asc.onlyoffice.ONLYOFFICE org.oasis-open.opendocument.text all
      asc.onlyoffice.ONLYOFFICE org.oasis-open.opendocument.spreadsheet all
      asc.onlyoffice.ONLYOFFICE org.oasis-open.opendocument.presentation all
      asc.onlyoffice.ONLYOFFICE com.adobe.pdf all
    '';
    system.defaults.CustomUserPreferences."asc.onlyoffice.ONLYOFFICE" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
    environment.systemPackages = [
      (inputs.brew-nix.packages.${pkgs.stdenv.hostPlatform.system}.onlyoffice.overrideAttrs {
        dontFixup = true;
      })
    ];
  };
}
