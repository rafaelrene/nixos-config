{
  lib,
  pkgs,
  home,
}:
let
  state = "${home}/.local/state/t3code-bundle-updater";
  profile = "${home}/.local/state/nix/profiles/t3code";
in
pkgs.writeShellApplication {
  name = "update-t3code";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    gnused
    jq
    nix
    nix-update
    flock
  ];
  text = ''
    export NIX_CONFIG="experimental-features = nix-command flakes
    accept-flake-config = false"
    install -d -m 0700 ${lib.escapeShellArg state}
    cd ${lib.escapeShellArg state}
    echo "T3 Code: waiting for any existing update..."
    exec 9>update.lock
    flock 9
    cp --update=none ${./package}/*.nix .
    chmod u+w ./*.nix
    if ! test -d .git; then git init -q; fi
    git add flake.nix package.nix desktop.nix
    nix flake update --no-accept-flake-config
    git add flake.lock
    current=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' package.nix)
    latest=$(curl --fail --silent --show-error --retry 3 https://registry.npmjs.org/t3 | jq -er '."dist-tags".nightly')
    echo "T3 Code: packaged $current, latest $latest"
    if test "$latest" != "$current"; then
      if ! nix-update --flake --version "$latest" t3code-nightly \
        || ! nix-update --flake --version "$latest" t3code-desktop; then
        git restore package.nix desktop.nix flake.lock
        echo "T3 Code: update failed; the installed generation is unchanged." >&2
        exit 1
      fi
    fi
    if ! new=$(nix build --print-build-logs --no-link --print-out-paths --no-accept-flake-config .#default); then
      git restore package.nix desktop.nix flake.lock
      exit 1
    fi
    mkdir -p "$(dirname ${lib.escapeShellArg profile})"
    if test "$new" != "$(readlink -f ${lib.escapeShellArg profile} || true)"; then
      nix-env --profile ${lib.escapeShellArg profile} --set "$new"
    fi
    git add package.nix desktop.nix flake.lock
    echo "T3 Code: server and desktop staged. Reopen the desktop after restarting the server."
  '';
}
