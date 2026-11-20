{ config, ... }:
{
  flake.modules.nixos.personal-applications.imports = [
    (config.features.modulesFor "nixos").webapps
  ];
  flake.modules.darwin = {
    personal-applications.imports = with (config.features.modulesFor "darwin"); [
      communication
      freetube
      personal-data
      webapps
    ];
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
      onlyoffice
      proton-pass
      standard-notes
    ];
  };
}
