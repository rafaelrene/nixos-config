{ config, ... }:
let
  inherit (config) features;
  shared = (features.modulesFor "generic").openssh;
  checkoutSource =
    config:
    features.sources.checkoutPath {
      inherit (config.workstation) checkout;
      source = ./.;
    };
in
{
  flake.modules = {
    generic.openssh =
      { config, ... }:
      let
        source = checkoutSource config;
      in
      {
        # Accepted host keys update the checkout, only as its workstation user.
        programs.ssh.extraConfig = ''
          Match localuser ${config.workstation.user}
            GlobalKnownHostsFile /dev/null
            UserKnownHostsFile ${source}/known_hosts
          Match all
        '';
      };

    nixos.openssh =
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
        source = checkoutSource config;
      in
      {
        imports = [ shared ];
        services.openssh = {
          enable = true;
          openFirewall = false;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };
        programs.ssh = {
          startAgent = true;
          extraConfig = ''
            Match localuser ${user}
              IdentityAgent /run/user/%i/ssh-agent
            Match all
          '';
        };
        # The desktop enables GNOME Keyring, which otherwise adds a second agent.
        services.gnome.gcr-ssh-agent.enable = false;

        systemd.tmpfiles.rules = [
          "d ${home}/.ssh 0700 ${user} ${group} - -"
          "L ${home}/.ssh/config - - - - ${source}/hosts.config"
          # File replacement must not restore the shared checkout's group-write ACL.
          "a+ ${source} - - - - d:m::r-x"
          "z ${source}/config 0644 - - - -"
          "z ${source}/hosts.config 0644 - - - -"
          "z ${source}/known_hosts 0644 - - - -"
        ];

        # Replace only our legacy wrapper link; leave independently managed config alone.
        system.userActivationScripts.ssh-config = ''
          if [ "$(${pkgs.coreutils}/bin/id -un)" = ${lib.escapeShellArg user} ]; then
            ssh=${lib.escapeShellArg "${home}/.ssh"}
            if [ -L "$ssh/config" ] && [ "$(${pkgs.coreutils}/bin/readlink "$ssh/config")" = "${source}/config" ]; then
              ${pkgs.coreutils}/bin/ln -sfn ${lib.escapeShellArg "${source}/hosts.config"} "$ssh/config"
            fi
            if [ -L "$ssh/hosts.config" ] && [ "$(${pkgs.coreutils}/bin/readlink "$ssh/hosts.config")" = "${source}/hosts.config" ]; then
              ${pkgs.coreutils}/bin/rm "$ssh/hosts.config"
            fi
          fi
        '';
      };

    darwin.openssh =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        user = config.workstation.user;
        home = config.users.users.${user}.home;
        source = checkoutSource config;
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
      in
      {
        imports = [ shared ];
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
      };
  };
}
