{ config, ... }:
let
  inherit (config.features) modulesFor;
in
{
  flake.modules = {
    generic.system = {
      environment.variables = {
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
      };
    };
    nixos.system =
      {
        config,
        lib,
        options,
        ...
      }:
      let
        user = config.workstation.user;
        inherit (config.users.users.${user}) home group;
      in
      {
        imports = [
          (modulesFor "generic").system
        ]
        ++ (with (modulesFor "nixos"); [
          nix
          boot
          networking
        ]);

        security = {
          polkit.enable = true;
          rtkit.enable = true;
          sudo = {
            enable = true;
            wheelNeedsPassword = true;
          };
        };

        services.fwupd.enable = true;
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
    darwin.system = {
      imports = [
        (modulesFor "generic").system
        (modulesFor "darwin").nix
        (modulesFor "darwin").networking
      ];
      homebrew.enable = false;
    };
  };
}
