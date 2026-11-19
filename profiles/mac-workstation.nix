{ config, ... }:
let
  modules = config.features.modulesFor "darwin";
in
{
  flake.modules.darwin.mac-workstation =
    { config, ... }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
    in
    {
      imports = with modules; [
        workstation
        desktop-workstation
      ];

      system.primaryUser = user;
      time.timeZone = "Europe/Bratislava";
      users.users.${user}.home = "/Users/${user}";
      workstation = {
        codeRoot = "${home}/code";
        checkout = "${home}/code/.personal/nixos-config";
      };
    };
}
