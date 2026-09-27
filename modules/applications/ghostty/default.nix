{ config, ... }:
let
  inherit (config) features;
  renderTheme =
    { lib, pkgs, ... }:
    let
      theme = features.theme { inherit lib pkgs; };
      inherit (theme) colors;
      terminalColors = with colors; [
        surface1
        red
        green
        yellow
        blue
        pink
        teal
        subtext1
        surface2
        red
        green
        yellow
        blue
        pink
        teal
        subtext0
      ];
    in
    ''
      font-family = ${theme.font.monospace}
      background = ${colors.base}
      foreground = ${colors.text}
      cursor-color = ${theme.accentColor}
      cursor-text = ${colors.crust}
      selection-background = ${colors.surface2}
      selection-foreground = ${colors.text}
    ''
    + lib.concatStringsSep "\n" (
      lib.imap0 (index: color: "palette = ${toString index}=${color}") terminalColors
    )
    + "\n";
  common = { lib, pkgs, ... }: {
    environment = {
      systemPackages = [
        (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty)
      ];
      etc = {
        "xdg/ghostty/common".source = "${./config-common}";
        "xdg/ghostty/theme".text = renderTheme { inherit lib pkgs; };
      };
    };
  };
in
{
  flake.modules = {
    nixos.ghostty =
      { config, ... }:
      let
        user = config.workstation.user;
        home = config.users.users.${user}.home;
        group = config.users.users.${user}.group;
      in
      {
        imports = [ common ];
        systemd.tmpfiles.rules = [
          "d ${home}/.config/ghostty 0700 ${user} ${group} - -"
          "L+ ${home}/.config/ghostty/config - - - - ${config.workstation.checkout}/modules/applications/ghostty/config"
        ];
      };
    darwin.ghostty = { config, ... }: {
      imports = [ common ];
      workstation.links.".config/ghostty/config" =
        "${config.workstation.checkout}/modules/applications/ghostty/darwin.config";
    };
  };
}
