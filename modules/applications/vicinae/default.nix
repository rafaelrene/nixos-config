{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../../../themes { inherit lib pkgs; };
  vicinaeTheme = pkgs.writeText "vicinae-theme.json" (
    builtins.toJSON {
      font.normal.family = theme.font.interface;
      theme = {
        light = {
          name = theme.vicinae;
          icon_theme = theme.icons.name;
        };
        dark = {
          name = theme.vicinae;
          icon_theme = theme.icons.name;
        };
      };
    }
  );
in
{
  environment.systemPackages = [ pkgs.vicinae ];
  systemd.user.services.vicinae = {
    description = "Vicinae launcher";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [
      config.system.path
      pkgs.pulseaudio
    ];
    # Native overrides apply styling without replacing writable user settings.
    environment.VICINAE_OVERRIDES = toString vicinaeTheme;
    unitConfig.ConditionUser = "raf";
    serviceConfig = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server --replace";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/raf/.config/vicinae 0700 raf raf - -"
    "C /home/raf/.config/vicinae/config.json 0600 raf raf - ${./config.json}"
  ];
}
