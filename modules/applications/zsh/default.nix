{ config, ... }:
let
  inherit (config) features;
  common =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
    in
    {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        histFile = "$HOME/.local/state/zsh/history";
        # Global Nix configuration replaces zsh's first-run setup wizard.
        shellInit = ''
          zsh-newuser-install() { :; }
        '';
        interactiveShellInit = ''
          source ${
            features.zsh.configuration {
              inherit lib pkgs;
              inherit (config.workstation) checkout codeRoot;
              hostname = config.networking.hostName;
            }
          }
        '';
      };
      users.users.${config.workstation.user}.shell =
        if pkgs.stdenv.hostPlatform.isDarwin then runtimes.zsh else pkgs.zsh;
      environment = {
        variables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
        };
        shellAliases = {
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
    };
in
{
  flake.modules.nixos.zsh =
    { config, ... }:
    {
      imports = [ common ];
      environment.localBinInPath = true;
      # Retire the old system-managed shell configuration on the next switch.
      systemd.tmpfiles.rules = [
        "r ${config.users.users.${config.workstation.user}.home}/.config/nushell/config.nu - - - -"
        "r ${config.users.users.${config.workstation.user}.home}/.config/nushell/env.nu - - - -"
      ];
    };
  flake.modules.darwin.zsh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
    in
    {
      imports = [ common ];
      environment = {
        shells = [ runtimes.zsh ];
        systemPath = lib.mkBefore [
          "$HOME/.local/bin"
          "$HOME/.orbstack/bin"
        ];
        variables = {
          SHELL = runtimes.zsh;
          LANG = "en_US.UTF-8";
          LC_ALL = "en_US.UTF-8";
        };
      };
      # Darwin only installs environment aliases in login shells by default.
      programs.zsh.interactiveShellInit = lib.mkBefore config.system.build.setAliases.text;
      # Only shell settings are managed for the existing macOS administrator.
      system.activationScripts.postActivation.text =
        lib.mkIf (!(builtins.elem config.workstation.user config.users.knownUsers))
          ''
            /usr/bin/dscl . -create ${lib.escapeShellArg "/Users/${config.workstation.user}"} UserShell ${lib.escapeShellArg runtimes.zsh}
          '';
    };
}
