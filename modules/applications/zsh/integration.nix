{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.generic.shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.zsh.interactiveShellInit = lib.mkOrder 900 ''
        source ${
          features.zsh.configuration {
            inherit lib pkgs;
            inherit (config.workstation) codeRoot;
          }
        }
      '';

      environment.shellAliases = {
        ls = "eza -la --icons=auto --group-directories-first";
        gs = "git status";
        gf = "git fetch";
        gp = "git merge --ff-only --autostash '@{upstream}'";
        gl = "git log --graph --color=auto --pretty=tformat:'%C(yellow)%h%C(reset) %C(green)%d%C(reset) %s %C(dim white)(%ar) <%an>%C(reset)'";
        gll = "git log --color=auto --date=format:'%Y-%m-%d %H:%M' --pretty=tformat:'%C(yellow)%H%C(reset) %C(green)%D%C(reset)%n%C(dim white)%ad  %an%C(reset)%n%n    %C(bold)%s%C(reset)%n%n%w(0,4,4)%b%w(0,0,0)%n'";
        vim = "nvim";
        v = "nvim";
        pn = "pnpm";
      };
    };
}
