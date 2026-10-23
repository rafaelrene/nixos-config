setopt ERR_EXIT NO_UNSET PIPE_FAIL

settings_file=$1
shift
settings=$(cat "$settings_file")
profile=$(jq -er '.profile' <<<"$settings")
staged=$(jq -er '.staged' <<<"$settings")
bundle=$(jq -er '.bundle' <<<"$settings")
flake=$(jq -er '.flake' <<<"$settings")
build_source=$(jq -er '.source' <<<"$settings")
output=$(jq -er '.output' <<<"$settings")
darwin=$(jq -r '.darwin // false | tostring' <<<"$settings")
stage=false
activate_only=false
migrate_only=false
checkout=''
while (( $# )); do
  case "$1" in
    --help|-h) print -- "Usage: update-llm-agents [--stage | --activate | --migrate] [--flake CHECKOUT]"; exit 0 ;;
    --stage) stage=true ;;
    --activate) activate_only=true ;;
    --migrate) migrate_only=true ;;
    --flake)
      (( $# >= 2 )) || { print -u2 -- "--flake requires a checkout."; exit 2; }
      checkout=$2; shift ;;
    *) print -u2 -- "Unknown option: $1"; exit 2 ;;
  esac
  shift
done
if [[ "$stage" == true && "$activate_only" == true ||
  "$migrate_only" == true && ( "$stage" == true || "$activate_only" == true ) ]]; then
  print -u2 -- 'Use only one of --stage, --activate, or --migrate.'
  exit 1
fi

resolved() {
  readlink -f "$1" 2>/dev/null || true
}
install_executables() {
  [[ "$darwin" == true ]] || return 0
  local generation=$1 installer="$1/share/darwin-identity/install" metadata literal identity_generation
  if [[ ! -x "$installer" ]]; then
    # Keep installed versions while adding identities to pre-migration profiles.
    metadata=$(jq -ce --arg profile "$profile" '
      {path: .source.path, hash: .source.hash, releases: .releases, profile: $profile} |
      select(.path | test("^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._=-]+$")) |
      select(.hash | test("^sha256-[A-Za-z0-9+/]{43}=$")) |
      select(.releases | [.codex, .["claude-code"]] | all(
        (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        (.hashes | [."aarch64-darwin", ."x86_64-linux"] | all(test("^[a-f0-9]{64}$")))))
    ' "$generation/share/llm-agents/release.json") || return
    literal=$(jq -Rn --arg metadata "$metadata" '$metadata' | sed 's/\${/\\${/g') || return
    identity_generation=$(nix build --print-build-logs --no-link --print-out-paths \
      --expr "$bundle (builtins.fromJSON $literal)") || return
    nix-env --profile "${profile}-identity-generation" --set "$identity_generation" || return
    installer="$identity_generation/share/darwin-identity/install"
  fi
  "$installer"
}
activate() {
  if [[ ! -e "$staged" ]]; then
    if [[ -e "$profile" ]]; then install_executables "$(resolved "$profile")"; fi
    print -- 'Agent tools: no staged release.'
    return
  fi
  local generation=$(resolved "$staged") old=$(resolved "$profile") code
  if install_executables "$generation"; then
    :
  else
    code=$?
    if [[ -n "$old" && "$old" != "$generation" ]]; then
      if install_executables "$old"; then
        print -u2 -- 'Agent tools: activation failed; the previous executable versions were restored.'
      else
        print -u2 -- 'Agent tools: activation and executable recovery failed. The previous profile is retained; retry update-llm-agents --activate.'
      fi
    fi
    return "$code"
  fi
  if [[ "$generation" == "$old" ]]; then
    print -- 'Agent tools: already active.'
    return
  fi
  nix-env --profile "$profile" --set "$generation"
  print -- 'Agent tools: activated for new sessions.'
}
if [[ "$migrate_only" == true ]]; then
  if [[ -e "$profile" ]]; then
    install_executables "$(resolved "$profile")"
    print -- 'Agent tools: current executable identities prepared.'
  else
    print -- 'Agent tools: no active release to migrate.'
  fi
  exit
fi
if [[ "$activate_only" == true ]]; then
  activate
  exit
fi

build_options=(--no-write-lock-file --no-accept-flake-config)
if [[ -n "$checkout" ]]; then
  build_source=$checkout
else
  # Scheduled checks refresh only this maintained input, using installed recipes.
  build_options+=(--refresh --override-input llm-agents "$flake")
fi
print -- "Agent tools: building the Nix package selection..."
generation=$(nix build --print-build-logs --no-link --print-out-paths "${build_options[@]}" "$build_source#$output")
if [[ "$generation" != "$(resolved "$staged")" ]]; then
  mkdir -p "${staged:h}"
  nix-env --profile "$staged" --set "$generation"
  print -- "Agent tools: staged."
else
  print -- "Agent tools: already staged."
fi
# Background checks may bootstrap; a manual system upgrade activates afterward.
if [[ "$stage" != true || ( ! -e "$profile" && -z "$checkout" ) ]]; then
  activate
fi
