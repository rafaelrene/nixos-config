{ config, lib, ... }:
{
  options.features.coding-agents.wrapper = lib.mkOption {
    type = lib.types.functionTo lib.types.package;
    description = "Build an agent launcher that enters the project development shell.";
  };

  config.features.coding-agents.wrapper =
    {
      pkgs,
      profile,
      name,
      installCommand ? "update-llm-agents",
    }:
    let
      executableDirectory =
        if pkgs.stdenv.hostPlatform.isDarwin then "${profile}-executables/bin" else "${profile}/bin";
    in
    config.features.shell.application {
      inherit pkgs;
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.devenv
      ];
      text = ''
        real="${executableDirectory}/${name}"
        if ! test -x "$real"; then
          echo "${name} is not installed yet. Run: ${installCommand}" >&2
          exit 1
        fi

        dir="$PWD"
        project=""
        while true; do
          if test -e "$dir/devenv.nix" || test -e "$dir/devenv.yaml"; then
            project="$dir"
            break
          fi
          if test "$dir" = /; then
            break
          fi
          dir="$(dirname "$dir")"
        done

        if test -n "$project" && test "''${DEVENV_ROOT:-}" != "$project"; then
          cd "$project"
          exec devenv shell -- "$real" "$@"
        fi

        exec "$real" "$@"
      '';
    };
}
