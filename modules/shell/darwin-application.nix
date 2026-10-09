{ config, lib, ... }:
{
  options.features.shell.darwinApplication = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Create a Darwin shell launcher using the stable Nix Bash executable.";
  };

  config.features.shell.darwinApplication =
    { pkgs, ... }@args:
    assert pkgs.stdenv.hostPlatform.isDarwin;
    let
      runtimes = config.features.shell.runtimes { inherit pkgs; };
    in
    (pkgs.writeShellApplication (
      (removeAttrs args [ "pkgs" ])
      // {
        text = ''
          export PATH="${runtimes.directory}:$PATH"
        ''
        + args.text;
      }
    )).overrideAttrs
      (previous: {
        # Keep Nix's runtime dependencies and ShellCheck, changing only this launcher.
        dontPatchShebangs = true;
        text =
          let
            shebang = "#!${pkgs.runtimeShell}\n";
          in
          assert lib.hasPrefix shebang previous.text;
          "#!${runtimes.bash}\n" + lib.removePrefix shebang previous.text;
        checkPhase = previous.checkPhase + ''
          ${pkgs.bash}/bin/bash -n "$target"
        '';
      });
}
