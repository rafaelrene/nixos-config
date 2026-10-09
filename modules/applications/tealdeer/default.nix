let
  common = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.tealdeer ];
    environment.variables.TEALDEER_CONFIG_DIR = "$HOME/.config/tealdeer";
  };
in
{
  flake.modules = {
    nixos.tealdeer =
      { config, ... }:
      let
        user = config.workstation.user;
        home = config.users.users.${user}.home;
        group = config.users.users.${user}.group;
      in
      {
        imports = [ common ];
        systemd.tmpfiles.rules = [
          "d ${home}/.config/tealdeer 0755 ${user} ${group} - -"
          "L+ ${home}/.config/tealdeer/config.toml - - - - ${./config.toml}"
        ];
      };
    darwin.tealdeer = {
      imports = [ common ];
      workstation.links.".config/tealdeer/config.toml" = "${./config.toml}";
    };
  };
}
