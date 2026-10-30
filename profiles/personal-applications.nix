{ config, ... }:
let
  shared =
    platform: with (config.features.modulesFor platform); [
      ghostty
      helium
      mpv
      tailscale
      webapps
      zen
    ];
in
{
  flake.modules.nixos.personal-applications.imports = shared "nixos";
  flake.modules.darwin = {
    personal-applications.imports =
      shared "darwin"
      ++ (with (config.features.modulesFor "darwin"); [
        communication
        personal-data
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
