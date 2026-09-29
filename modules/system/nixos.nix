{
  flake.modules.nixos.system =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      user = config.workstation.user;
      home = config.users.users.${user}.home;
      group = config.users.users.${user}.group;
    in
    {
      security = {
        polkit.enable = true;
        rtkit.enable = true;
        sudo = {
          enable = true;
          wheelNeedsPassword = true;
        };
      };

      services.fwupd.enable = true;
      services.power-profiles-daemon.enable = true;
      environment = {
        localBinInPath = true;
        # Packaged Perl consumers retain their own interpreter dependency.
        defaultPackages = builtins.filter (
          package: lib.getName package != "perl"
        ) options.environment.defaultPackages.default;
      };
      systemd.tmpfiles.rules = [
        "d ${home}/.cache 0700 ${user} ${group} - -"
        "d ${home}/.config 0700 ${user} ${group} - -"
        "d ${home}/.local 0700 ${user} ${group} - -"
        "d ${home}/.local/bin 0755 ${user} ${group} - -"
        "d ${home}/.local/share 0700 ${user} ${group} - -"
        "d ${home}/.local/state 0700 ${user} ${group} - -"
      ];
    };
}
