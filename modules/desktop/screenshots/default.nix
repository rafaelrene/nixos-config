{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../../../themes { inherit lib pkgs; };
  sattyConfig = (pkgs.formats.toml { }).generate "satty-config.toml" {
    general = {
      copy-command = "${pkgs.wl-clipboard}/bin/wl-copy --type image/png";
      early-exit = true;
      save-after-copy = false;
      actions-on-enter = [
        "save-to-clipboard"
        "exit"
      ];
      actions-on-escape = [ "exit" ];
    };
    color-palette.palette = map (name: "#${theme.colors.${name}}") [
      theme.accent
      "red"
      "peach"
      "yellow"
      "green"
      "teal"
      "blue"
      "text"
      "base"
    ];
  };
  annotateScreenshots = pkgs.writeShellApplication {
    name = "annotate-screenshots";
    runtimeInputs = [
      config.programs.niri.package
      pkgs.jq
      pkgs.wl-clipboard
      pkgs.satty
    ];
    text = ''
      export SATTY_CONFIG=${sattyConfig}
      ${builtins.readFile ./annotate-screenshots.sh}
    '';
  };
in
{
  environment.systemPackages = [ pkgs.satty ];

  systemd.user.services.screenshot-annotation = {
    description = "Annotate Niri screenshots in Satty";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    unitConfig.ConditionUser = "raf";
    serviceConfig = {
      ExecStart = lib.getExe annotateScreenshots;
      Restart = "always";
      RestartSec = 1;
    };
  };
}
