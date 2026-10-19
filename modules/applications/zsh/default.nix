{ config, ... }:
let
  inherit (config) features;
  common =
    {
      config,
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
      };
      users.users.${config.workstation.user}.shell =
        if pkgs.stdenv.hostPlatform.isDarwin then runtimes.zsh else pkgs.zsh;
    };
in
{
  flake.modules.nixos.zsh = {
    imports = [ common ];
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
