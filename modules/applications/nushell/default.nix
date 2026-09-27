{ config, ... }:
let
  inherit (config) features;
  configuration =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    features.nushell.configuration {
      inherit lib pkgs;
      checkout = config.workstation.checkout;
      hostname = config.networking.hostName;
      rebuildCommand =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "sudo darwin-rebuild switch"
        else
          "sudo nixos-rebuild switch";
    };
in
{
  flake.modules.nixos.nushell =
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
      nuConfig = configuration { inherit config lib pkgs; };
    in
    {
      users.users.${user}.shell = pkgs.nushell;
      programs.bash.completion.enable = true;
      systemd.tmpfiles.rules = [
        "d ${home}/.config/nushell 0700 ${user} ${group} - -"
        "L+ ${home}/.config/nushell/config.nu - - - - ${nuConfig}"
      ];
    };
  flake.modules.darwin.nushell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      nuConfig = configuration { inherit config lib pkgs; };
    in
    {
      environment = {
        systemPackages = [ pkgs.nushell ];
        systemPath = lib.mkBefore [ "$HOME/.local/bin" ];
        shells = [ "/nix/var/nix/profiles/system/sw/bin/nu" ];
        variables = {
          LANG = "en_US.UTF-8";
          LC_ALL = "en_US.UTF-8";
        };
        etc."nushell/environment.json".text = builtins.toJSON (
          lib.mapAttrs (_: value: lib.replaceStrings [ "$HOME" ] [ home ] value) config.environment.variables
        );
      };
      programs.zsh.enable = true;
      workstation.links = {
        ".config/nushell/config.nu" = toString nuConfig;
        ".config/nushell/env.nu" = toString ./env.nu;
        "Library/Application Support/nushell/env.nu" = toString ./env.nu;
        "Library/Application Support/nushell/config.nu" = toString nuConfig;
      };
      # Keep ownership of the existing admin account with macOS.
      system.activationScripts.postActivation.text = ''
        /usr/bin/dscl . -create ${lib.escapeShellArg "/Users/${user}"} UserShell /nix/var/nix/profiles/system/sw/bin/nu
      '';
    };
}
