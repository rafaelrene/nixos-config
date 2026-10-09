{ lib, ... }:
{
  options.features.shell.darwinApplication = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Create a Darwin shell launcher using Apple's stable /bin/bash identity.";
  };

  config.features.shell.darwinApplication =
    { pkgs, ... }@args:
    assert pkgs.stdenv.hostPlatform.isDarwin;
    (pkgs.writeShellApplication (removeAttrs args [ "pkgs" ])).overrideAttrs (previous: {
      # Keep Nix's runtime dependencies and ShellCheck, changing only this launcher.
      dontPatchShebangs = true;
      text =
        let
          shebang = "#!${pkgs.runtimeShell}\n";
        in
        assert lib.hasPrefix shebang previous.text;
        "#!/bin/bash\n" + lib.removePrefix shebang previous.text;
      checkPhase = previous.checkPhase + ''
        /bin/bash -n "$target"
      '';
    });
}
