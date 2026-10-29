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
release_directory=$(jq -er '.releaseDirectory' <<<"$settings")
resolver=$(jq -er '.resolverCommand' <<<"$settings")
state=$(jq -er '.state' <<<"$settings")
darwin=$(jq -er '.darwin | tostring' <<<"$settings")
project=$(jq -r '.project // empty' <<<"$settings")
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
  local generation previous version snapshot
  local -a build_options=(--no-write-lock-file --no-accept-flake-config)
  if [[ -n "$checkout" ]]; then
    build_source=$checkout
    snapshot="$checkout/$release_directory"
    [[ -f "$snapshot/release.json" ]] || { print -u2 -- "Checkout has no T3 release snapshot: $snapshot/release.json"; return 1; }
  else
    snapshot="$state/release"
    build_options+=(--override-input t3-release "path:$snapshot")
  fi
  update_step 'discovering the official nightly release' "$resolver" "$snapshot/release.json" || return
  print -- "T3 Code: building the matching Nix server and desktop..."
  previous=$(readlink -f "$staged" 2>/dev/null) || previous=''
  mkdir -p "$base" || return
  # Retain a GC root while the lifecycle waits to promote under its activation lock.
  update_step 'building the server and desktop' nix build --print-build-logs --out-link "$base/.t3code-build" "${build_options[@]}" "$build_source#$output" || return
  generation=$(readlink -f "$base/.t3code-build") || return
  if [[ "$generation" == "$previous" ]]; then
    print -- "T3 Code: server and desktop are already staged."
    changed=false
    return
  fi
  update_step 'staging the release' "$lifecycle" stage "$generation" || return
  version=$(jq -er '.version' "$generation/share/t3code/release.json") || return
  print -- "T3 Code: server and desktop $version staged."
  update_success="Server and desktop $version staged."
  changed=true
}
server="$profile/bin/t3"
if [[ "$darwin" == true ]]; then server="${profile}-executables/bin/t3"; fi
changed=false
if [[ "$bootstrap" != true || ! -e "$server" ]]; then
  if ! update; then
    print -u2 -- 'T3 Code: update failed. No server restart requested. The previous staged and active releases are retained.'
    exit 1
  fi
fi
if [[ "$bootstrap" == true && ! -e "$server" ]]; then
  update_step 'bootstrapping the release' "$lifecycle" seed || exit $?
fi
if [[ -n "$project" && -x "$server" && ! -e "$base/.nixos-config-registered" ]]; then
  install -d -m 0700 "$base"
  update_step 'registering the configuration project' "$server" project add "$project" --base-dir "$base" || exit $?
  touch "$base/.nixos-config-registered"
fi
if [[ "$restart" == true ]]; then
  # Bootstrap may need this same lock when the server starts for the first time.
  flock -u 9
  # The coordinator reports success only after checking the running release.
  update_success=''
  update_step 'activating the staged release' "$lifecycle" request || exit $?
elif [[ "$changed" == true ]]; then
  print -- 'T3 Code: release staged for ns, t3-activate, or the 04:00 activation.'
fi
