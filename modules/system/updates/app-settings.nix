{ lib, ... }:
{
  options.features.updates.darwinAppSettings = lib.mkOption {
    type = lib.types.functionTo lib.types.deferredModule;
    description = "Merge native updater preferences while the application is closed.";
  };

  config.features.updates.darwinAppSettings =
    app:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
      run =
        phase:
        lib.escapeShellArgs [
          "/usr/bin/sudo"
          "-H"
          "-u"
          config.system.primaryUser
          "--"
          "${python}/bin/python3"
          "${./app-settings.py}"
          app
          phase
        ];
    in
    {
      system.activationScripts = {
        preActivation.text = lib.mkBefore ''
          ${run "check"}
        '';
        postActivation.text = lib.mkAfter ''
          ${run "apply"}
        '';
      };
    };
}
