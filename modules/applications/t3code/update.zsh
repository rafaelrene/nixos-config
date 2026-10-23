setopt ERR_EXIT NO_UNSET PIPE_FAIL

settings_file=$1
shift
settings=$(cat "$settings_file")
profile=$(jq -er '.profile' <<<"$settings")
staged=$(jq -er '.staged' <<<"$settings")
base=$(jq -er '.base' <<<"$settings")
lifecycle=$(jq -er '.lifecycle' <<<"$settings")
build_source=$(jq -er '.source' <<<"$settings")
output=$(jq -er '.output' <<<"$settings")
server_input=$(jq -er '.serverInput' <<<"$settings")
desktop_input=$(jq -er '.desktopInput' <<<"$settings")
darwin=$(jq -er '.darwin | tostring' <<<"$settings")
project=$(jq -r '.project // empty' <<<"$settings")
activate_command=$(jq -er '.activateCommand' <<<"$settings")
restart=false
bootstrap=false
checkout=''
while (( $# )); do
  case "$1" in
    --help|-h) print -- "Usage: update-t3code [--restart] [--bootstrap] [--flake CHECKOUT]"; exit 0 ;;
    --restart) restart=true ;;
    --bootstrap) bootstrap=true ;;
    --flake)
      (( $# >= 2 )) || { print -u2 -- "--flake requires a checkout."; exit 2; }
      checkout=$2; shift ;;
    *) print -u2 -- "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

update() {
  local generation previous version
  local -a build_options=(--no-write-lock-file --no-accept-flake-config)
  if [[ -n "$checkout" ]]; then
    build_source=$checkout
  else
    # Nix resolves nightly versions and publisher hashes from the release input.
    build_options+=(--refresh
      --override-input t3-server-releases "$server_input"
      --override-input t3-desktop-releases "$desktop_input")
  fi
  print -- "T3 Code: building the matching Nix server and desktop..."
  generation=$(nix build --print-build-logs --no-link --print-out-paths "${build_options[@]}" "$build_source#$output") || return
  previous=$(readlink -f "$staged" 2>/dev/null) || previous=''
  if [[ "$generation" == "$previous" ]]; then
    print -- "T3 Code: server and desktop are already staged."
    changed=false
    return
  fi
  "$lifecycle" stage "$generation" || return
  version=$(jq -er '.version' "$generation/share/t3code/release.json") || return
  print -- "T3 Code: server and desktop $version staged."
  changed=true
}
server="$profile/bin/t3"
if [[ "$darwin" == true ]]; then server="${profile}-executables/bin/t3"; fi
changed=false
if [[ "$bootstrap" != true || ! -e "$server" ]]; then
  if ! update; then
    print -u2 -- 'T3 Code: update failed. No server restart requested. The update can be retried.'
    exit 1
  fi
fi
if [[ "$bootstrap" == true && ! -e "$server" ]]; then
  "$lifecycle" seed
fi
if [[ -n "$project" && -x "$server" && ! -e "$base/.nixos-config-registered" ]]; then
  install -d -m 0700 "$base"
  "$server" project add "$project" --base-dir "$base"
  touch "$base/.nixos-config-registered"
fi
if [[ "$restart" == true ]]; then
  # Bootstrap may need this same lock when the server starts for the first time.
  flock -u 9
  print -- 'T3 Code: requesting coordinated activation...'
  if [[ "$darwin" == true ]]; then
    "$activate_command" kickstart "gui/$(id -u)/org.nixos.t3code-restart"
  else
    "$activate_command" --user start --no-block t3code-restart.service
  fi
  print -- 'T3 Code: activation runs in the service manager; an open desktop will reopen automatically.'
elif [[ "$changed" == true ]]; then
  print -- 'T3 Code: release staged for ns -u, t3-activate, or the 04:00 activation.'
fi
