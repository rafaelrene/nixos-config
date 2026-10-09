{ config, lib, ... }:
{
  options.features.shell = {
    runtimes = lib.mkOption {
      type = lib.types.functionTo (lib.types.attrsOf lib.types.str);
      description = "Shell and Python executable paths for each platform.";
    };
    application = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      description = "Create a shell command with the platform's managed interpreter.";
    };
  };

  config.features.shell = {
    runtimes =
      { pkgs }:
      let
        darwin = pkgs.stdenv.hostPlatform.isDarwin;
        directory = "/var/lib/nix-darwin/bin";
      in
      {
        inherit directory;
        bash = if darwin then "${directory}/bash" else "${pkgs.bash}/bin/bash";
        zsh = if darwin then "${directory}/zsh" else lib.getExe pkgs.zsh;
        python3 = if darwin then "${directory}/python3" else lib.getExe pkgs.python3;
      };
    application =
      { pkgs, ... }@args:
      if pkgs.stdenv.hostPlatform.isDarwin then
        config.features.shell.darwinApplication args
      else
        pkgs.writeShellApplication (removeAttrs args [ "pkgs" ]);
  };
}
