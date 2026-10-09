setopt ERR_EXIT NO_UNSET PIPE_FAIL

settings_file=$1
shift
settings=$(cat "$settings_file")
profile=$(jq -er '.profile' <<<"$settings")
staged=$(jq -er '.staged' <<<"$settings")
base=$(jq -er '.base' <<<"$settings")
lifecycle=$(jq -er '.lifecycle' <<<"$settings")
bundle=$(jq -er '.bundle' <<<"$settings")
darwin=$(jq -er '.darwin | tostring' <<<"$settings")
project=$(jq -r '.project // empty' <<<"$settings")
activate_command=$(jq -er '.activateCommand' <<<"$settings")
restart=false
bootstrap=false
for argument in "$@"; do
  case "$argument" in
    --help|-h) print -- "Usage: update-t3code [--restart] [--bootstrap]"; exit 0 ;;
    --restart) restart=true ;;
    --bootstrap) bootstrap=true ;;
    *) print -u2 -- "Unknown option: $argument"; exit 1 ;;
  esac
done

prefetch_hash() {
  nix store prefetch-file --json "$1" | jq -er '.hash | select(type == "string")'
}

update() {
  print -- 'T3 Code: checking the nightly channel...'
  local version source metadata release platform desktop url server_hash desktop_hash expression previous expected generation
  version=$(curl --fail --silent --show-error --retry 3 https://registry.npmjs.org/t3 |
    jq -er '.["dist-tags"].nightly | select(type == "string")') || return
  if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9.]+$' ]]; then
    print -u2 -- 'The nightly channel returned an invalid version.'
    return 1
  fi
  source=$profile
  [[ ! -e "$staged" ]] || source=$staged
  metadata="$source/share/t3code/release.json"
  if [[ -f "$metadata" ]] && jq -e --arg version "$version" '.version == $version' "$metadata" >/dev/null; then
    release=$(cat "$metadata") || return
    server_hash=$(jq -er '.serverHash | select(type == "string")' <<<"$release") || return
    desktop_hash=$(jq -er '.desktopHash | select(type == "string")' <<<"$release") || return
  else
    platform=linux-x64
    desktop=x86_64.AppImage
    if [[ "$darwin" == true ]]; then
      platform=darwin-arm64
      desktop=arm64.zip
    fi
    url="https://github.com/pingdotgg/t3code/releases/download/v$version"
    print -- "T3 Code: downloading server and desktop $version..."
    server_hash=$(prefetch_hash "$url/t3-$version-$platform.tar.gz") || return
    desktop_hash=$(prefetch_hash "$url/T3-Code-$version-$desktop") || return
  fi
  local hash
  for hash in "$server_hash" "$desktop_hash"; do
    if [[ ! "$hash" =~ '^sha256-[A-Za-z0-9+/]{43}=$' ]]; then
      print -u2 -- 'Invalid T3 Code download hash.'
      return 1
    fi
  done
  local identity=''
  if [[ "$darwin" == true ]]; then identity="profile = $(jq -Rn --arg profile "$profile" '$profile' | sed 's/\${/\\${/g');"; fi
  expression="$bundle { version = \"$version\"; serverHash = \"$server_hash\"; desktopHash = \"$desktop_hash\"; $identity }"
  previous=$(readlink -f "$staged" 2>/dev/null) || previous=''
  expected=$(nix eval --raw --expr "($expression).outPath") || return
  if [[ "$expected" == "$previous" ]]; then
    print -- "T3 Code: server and desktop $version are already staged."
    changed=false
    return
  fi
  print -- "T3 Code: building server and desktop $version..."
  generation=$(nix build --print-build-logs --no-link --print-out-paths --expr "$expression") || return
  mkdir -p "${staged:h}" || return
  "$lifecycle" stage "$generation" || return
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
if [[ -n "$project" && ! -e "$base/.nixos-config-registered" ]]; then
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
  print -- 'T3 Code: release staged for ns, t3-activate, or the 04:00 activation.'
fi
