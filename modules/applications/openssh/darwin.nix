{ config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.openssh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      source = features.sources.checkoutPath {
        inherit (config.workstation) checkout;
        source = ./.;
      };
      restoreAgent = features.shell.darwinApplication {
        inherit pkgs;
        name = "restore-ssh-agent";
        text = ''
          if [[ -n "''${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
            mkdir -p ${lib.escapeShellArg "${home}/.ssh"}
            ln -sfn "$SSH_AUTH_SOCK" ${lib.escapeShellArg "${home}/.ssh/nix-agent.sock"}
          fi
          exec /usr/bin/ssh-add --apple-load-keychain
        '';
      };
      provision = lib.escapeShellArgs [
        "/usr/bin/sudo"
        "-H"
        "-u"
        user
        "--"
        runtimes.python3
        "${./ssh-keys.py}"
        "--repo"
        source
        "--home"
        home
        "--source"
        "${home}/.ssh"
        "--age"
        "${pkgs.age}/bin/age"
        "--ssh-keygen"
        "${pkgs.openssh}/bin/ssh-keygen"
        "--temporary-directory"
        "${home}/.ssh"
      ];
    in
    {
      environment.systemPackages = [ pkgs.openssh ];
      services.openssh.enable = true;
      programs.ssh.extraConfig = ''
        Match exec "test -z \"$SSH_AUTH_SOCK\" && test -S \"$HOME/.ssh/nix-agent.sock\""
          IdentityAgent ~/.ssh/nix-agent.sock
        Match all
      '';
      workstation.links.".ssh/config" = "${source}/hosts.config";
      launchd.user.agents.ssh-keys.serviceConfig = {
        ProgramArguments = [ (lib.getExe restoreAgent) ];
        RunAtLoad = true;
        StandardOutPath = "${home}/.local/state/nix-darwin/ssh-keys.log";
        StandardErrorPath = "${home}/.local/state/nix-darwin/ssh-keys.log";
      };
      # Run after existing preflight checks, before files or services are activated.
      # darwin-rebuild check also enters preActivation and must never provision keys.
      system.activationScripts.preActivation.text = lib.mkAfter ''
        if [ "''${checkActivation:-0}" != 1 ]; then
          ${provision}
        fi
      '';
    };
}
