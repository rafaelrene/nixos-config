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
        installKeys = pkgs.writeShellApplication {
          name = "install-managed-ssh-keys";
          runtimeInputs = [ pkgs.util-linux ];
          text = ''
            # Drop root before touching either the checkout or the user's files.
            exec runuser -u ${lib.escapeShellArg user} -- ${pkgs.python3}/bin/python3 ${./ssh-keys.py} \
              --repo ${lib.escapeShellArg source} \
              --home ${lib.escapeShellArg home} \
              --source ${lib.escapeShellArg "${home}/.ssh"} \
              --age ${pkgs.age}/bin/age \
              --script ${pkgs.util-linux}/bin/script \
              --ssh-keygen ${pkgs.openssh}/bin/ssh-keygen
          '';
        };
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

        # Run before activation so cancellation or a bad passphrase aborts the
        # switch. Boot, build and dry-activate must never wait for a passphrase.
        system.preSwitchChecks.sshKeys = ''
          if [ "$2" = switch ] || [ "$2" = test ]; then
            ${installKeys}/bin/install-managed-ssh-keys
          fi
        '';

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
        runtimes = features.shell.runtimes { inherit pkgs; };
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
        # Run after existing preflight checks, before files or services are activated.
        # darwin-rebuild check also enters preActivation and must never provision keys.
        system.activationScripts.preActivation.text = lib.mkAfter ''
          if [ "''${checkActivation:-0}" != 1 ]; then
            ${provision}
          fi
        '';
      };
  };
}
