{ config, ... }:
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
      executableSources = {
        bash = "${pkgs.bashInteractive}/bin/bash";
        zsh = lib.getExe pkgs.zsh;
        python3 = lib.getExe pkgs.python3;
        node = lib.getExe pkgs.nodejs_24;
      };
      sources = pkgs.writeText "darwin-executable-sources.json" (
        builtins.toJSON {
          bin = runtimes.directory;
          systemBin = "${config.system.path}/bin";
          applications = "${config.system.build.applications}/Applications";
          inherit executableSources;
          aliases = {
            sh = "bash";
            python = "python3";
          };
        }
      );
      payload =
        pkgs.runCommand "darwin-stable-executables"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.stdenv.cc
              pkgs.makeBinaryWrapper
              pkgs.darwin.cctools
            ];
          }
          ''
            python3 ${./build-executables.py} ${sources} "$out"
            source "$out/rebuild-wrappers.sh"
          '';
      manifest = pkgs.writeText "darwin-executable-identities.json" (
        builtins.toJSON {
          bin = runtimes.directory;
          state = "/var/lib/nix-darwin/code-signing";
          inherit payload;
          applications = "${config.system.build.applications}/Applications";
          installedApplications = "/Applications/Nix Apps";
          openssl = lib.getExe pkgs.openssl;
          bootstrapBash = executableSources.bash;
          bootstrapExecutables = executableSources;
          extraExecutables = config.workstation.darwinIdentity.executables;
        }
      );
      install =
        mode:
        lib.escapeShellArgs [
          "/usr/bin/python3"
          (toString ./install.py)
          (toString manifest)
          mode
        ];
    in
    {
      options.workstation.darwinIdentity.executables = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              source = lib.mkOption { type = lib.types.path; };
              destination = lib.mkOption { type = lib.types.path; };
              identifier = lib.mkOption { type = lib.types.str; };
            };
          }
        );
        default = { };
        description = "Additional permission-sensitive executables installed at fixed real paths.";
      };
      config = {
        environment.systemPath = lib.mkOrder 400 [ runtimes.directory ];
        launchd.user.envVariables.SHELL = runtimes.zsh;
        launchd.daemons = {
          activate-system.serviceConfig.ProgramArguments = lib.mkForce [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${runtimes.bash} ${lib.escapeShellArg config.launchd.daemons.activate-system.command}"
          ];
          nix-daemon = lib.mkIf config.nix.enable {
            command = lib.mkForce "${runtimes.directory}/nix-daemon";
            # The executable path stays fixed; package changes still reload the job.
            serviceConfig.EnvironmentVariables.NIX_DARWIN_PACKAGE = toString config.nix.package;
          };
          nix-gc = lib.mkIf config.nix.gc.automatic {
            command = lib.mkForce "${runtimes.directory}/nix-collect-garbage ${config.nix.gc.options}";
          };
        };
        system = {
          build = {
            darwinIdentityPayload = payload;
            darwinIdentityManifest = manifest;
          };
          activationScripts = {
            extraActivation.text = lib.mkBefore ''
              ${install "executables"}
            '';
            # nix-darwin copies the bundles first. Keep vendor signatures and sign
            # local builds with the same private machine identity on every switch.
            applications.text = lib.mkOrder 1600 ''
              ${install "applications"}
            '';
          };
        };
      };
    };
}
