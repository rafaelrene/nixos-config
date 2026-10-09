{ inputs, ... }:
{
  flake.modules.darwin.system =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Use upstream's argument parser and profile handling with a stable interpreter.
      tools = pkgs.callPackage "${inputs.nix-darwin}/pkgs/nix-tools" {
        stdenv = pkgs.stdenv // {
          shell = "/bin/bash";
        };
        inherit (config.system) profile;
        inherit (config.environment) systemPath;
        nixPath = lib.optionalString config.nix.enable (lib.concatStringsSep ":" config.nix.nixPath);
        nixPackage = if config.nix.enable then config.nix.package else null;
      };
      rebuild = tools.darwin-rebuild.overrideAttrs (previous: {
        # Nix's fixup otherwise rewrites /bin/bash back to the store interpreter.
        dontPatchShebangs = true;
        postInstall = previous.postInstall + ''
          /bin/bash -n "$out/bin/darwin-rebuild"
        '';
      });
      activation = config.system.activationScripts.script.text;
      activationShebang = "#!/usr/bin/env -i ${pkgs.stdenv.shell}\n";
    in
    {
      environment.systemPackages = [ rebuild ];
      system = {
        # ns and nups already call darwin-rebuild. Replace only the Darwin system tool.
        tools.darwin-rebuild.enable = false;
        build.darwin-rebuild = lib.mkForce rebuild;

        # Retain upstream activation order and its clean environment. A symlink to
        # Nix Bash would still identify the changing store executable in macOS TCC.
        systemBuilderArgs.activationScript =
          assert lib.hasPrefix activationShebang activation;
          "#!/usr/bin/env -i /bin/bash\n" + lib.removePrefix activationShebang activation;
        systemBuilderCommands = ''
          /bin/bash -n "$out/activate"
        '';
      };
    };
}
