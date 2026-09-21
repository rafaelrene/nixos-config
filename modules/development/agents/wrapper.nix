{
  pkgs,
  profile,
  name,
  installCommand ? "systemctl --user start llm-agents-update.service",
}:
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [
    pkgs.coreutils
    pkgs.devenv
  ];
  text = ''
    real="${profile}/bin/${name}"
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
}
