{ config, ... }:
let
  inherit (config) features;
  themeConfig =
    { lib, pkgs }:
    pkgs.writeText "git-theme.gitconfig" (
      lib.generators.toGitINI {
        inherit (features.theme { inherit lib pkgs; }) delta;
      }
    );
  common = { pkgs, ... }: {
    environment = {
      systemPackages = [ pkgs.git ];
      variables.GIT_CONFIG_GLOBAL = "$HOME/.config/git/config";
      shellAliases = {
        gs = "git status";
        gf = "git fetch";
        gp = "git merge --ff-only --autostash '@{upstream}'";
        gl = "git log --graph --color=auto --pretty=tformat:'%C(yellow)%h%C(reset) %C(green)%d%C(reset) %s %C(dim white)(%ar) <%an>%C(reset)'";
        gll = "git log --color=auto --date=format:'%Y-%m-%d %H:%M' --pretty=tformat:'%C(yellow)%H%C(reset) %C(green)%D%C(reset)%n%C(dim white)%ad  %an%C(reset)%n%n    %C(bold)%s%C(reset)%n%n%w(0,4,4)%b%w(0,0,0)%n'";
      };
    };
  };
in
{
  flake.modules.nixos.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
      source =
        path:
        features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = path;
        };
    in
    {
      imports = [ common ];
      systemd.tmpfiles.rules = [
        "d ${home}/.config/git 0700 ${user} ${group} - -"
        "L+ ${home}/.config/git/config - - - - ${source ./config}"
        "L+ ${home}/.config/git/ignore - - - - ${source ./ignore}"
        "L+ ${home}/.config/git/themes.gitconfig - - - - ${themeConfig { inherit lib pkgs; }}"
      ];
    };
  flake.modules.darwin.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      source =
        path:
        features.sources.checkoutPath {
          inherit (config.workstation) checkout;
          source = path;
        };
    in
    {
      imports = [ common ];
      workstation.links = {
        ".config/git/config" = source ./config;
        ".config/git/ignore" = source ./ignore;
        ".config/git/themes.gitconfig" = toString (themeConfig {
          inherit lib pkgs;
        });
      };
    };
}
