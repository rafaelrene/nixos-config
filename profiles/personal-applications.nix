{ config, ... }:
let
  shared =
    platform: with (config.features.modulesFor platform); [
      ghostty
      helium
      mpv
      personal-data
      tailscale
      webapps
      zen
    ];
in
{
  flake.modules.nixos = {
    personal-applications.imports = shared "nixos";
    personal-data.imports = [ (config.features.modulesFor "nixos").filen ];
  };
  flake.modules.darwin = {
    personal-applications.imports =
      shared "darwin"
      ++ (with (config.features.modulesFor "darwin"); [
        communication
        freetube
        rex
        rustdesk
        ungoogled-chromium
        zentty
      ]);
    communication.imports = with (config.features.modulesFor "darwin"); [
      discord
      mailspring
      microsoft-teams
      signal
      slack
      telegram
      viber
      whatsapp
    ];
    personal-data.imports = with (config.features.modulesFor "darwin"); [
      anytype
      ente
      ente-auth
      filen
      google-drive
      onlyoffice
      proton-drive
      proton-pass
      standard-notes
    ];
  };
}
