{ lib, ... }:
{
  options.features.updates.darwinAppSettings = lib.mkOption {
    type = lib.types.functionTo lib.types.deferredModule;
    description = "Merge application-declared native preferences while the application is closed.";
  };

  # Close the app before rebuilding if its managed preference changes. Settings
  # remain writable and are reapplied on each rebuild.
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
      settings = pkgs.writeText "native-app-settings.json" (builtins.toJSON app);
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
          (toString settings)
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
