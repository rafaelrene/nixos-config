{ inputs, config, ... }:
let
  inherit (config) features;
in
{
  flake.modules.darwin.system =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      runtimes = features.shell.runtimes { inherit pkgs; };
      tools = pkgs.callPackage "${inputs.nix-darwin}/pkgs/nix-tools" {
        stdenv = pkgs.stdenv // {
          shell = runtimes.bash;
        };
        inherit (config.system) profile;
        inherit (config.environment) systemPath;
        nixPath = lib.optionalString config.nix.enable (lib.concatStringsSep ":" config.nix.nixPath);
        nixPackage = if config.nix.enable then config.nix.package else null;
      };
      rebuild = tools.darwin-rebuild.overrideAttrs (previous: {
        dontPatchShebangs = true;
        postInstall = previous.postInstall + ''
          ${pkgs.bash}/bin/bash -n "$out/bin/darwin-rebuild"
        '';
      });
      activation = config.system.activationScripts.script.text;
      activationShebang = "#!/usr/bin/env -i ${pkgs.stdenv.shell}\n";
    in
    {
      environment.systemPackages = [ rebuild ];
      system = {
        tools.darwin-rebuild.enable = false;
        build.darwin-rebuild = lib.mkForce rebuild;
        # Apple's shell bootstraps the first installation, then hands activation
        # to the same locally signed Nix Bash used for every subsequent switch.
        systemBuilderArgs.activationScript =
          assert lib.hasPrefix activationShebang activation;
          ''
            #!/usr/bin/env -i /bin/bash
            # shellcheck shell=bash disable=SC2096
            if [ "$BASH" != ${lib.escapeShellArg runtimes.bash} ]; then
              if [ "$(/usr/bin/id -u)" -ne 0 ]; then
                printf >&2 'activate must be run as root\n'
                exit 2
              fi
              /usr/bin/python3 ${../darwin-identity/install.py} ${config.system.build.darwinIdentityManifest} bootstrap || exit $?
              exec ${runtimes.bash} "$0" "$@"
            fi
          ''
          + lib.removePrefix activationShebang activation;
        systemBuilderCommands = ''
          ${pkgs.bash}/bin/bash -n "$out/activate"
        '';
      };
    };
}
