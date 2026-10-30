setopt ERR_EXIT NO_UNSET PIPE_FAIL

settings_file=$1
shift
settings=$(cat "$settings_file")
profile=$(jq -er '.profile' <<<"$settings")
staged=$(jq -er '.staged' <<<"$settings")
flake=$(jq -er '.flake' <<<"$settings")
build_source=$(jq -er '.source' <<<"$settings")
output=$(jq -er '.output' <<<"$settings")
darwin=$(jq -r '.darwin | tostring' <<<"$settings")
command_name=$(jq -er '.commandName' <<<"$settings")
stage=false
activate_only=false
checkout=''
while (( $# )); do
  case "$1" in
    --help|-h) print -- "Usage: $command_name [--stage | --activate] [--flake CHECKOUT]"; exit 0 ;;
    --stage) stage=true ;;
    --activate) activate_only=true ;;
    --flake)
      (( $# >= 2 )) || { print -u2 -- "--flake requires a checkout."; exit 2; }
      checkout=$2; shift ;;
    *) print -u2 -- "Unknown option: $1"; exit 2 ;;
  esac
  shift
done
if [[ "$stage" == true && "$activate_only" == true ]]; then
  print -u2 -- 'Use only one of --stage or --activate.'
  exit 1
fi

install_executables() {
  [[ "$darwin" == true ]] || return 0
  "$1/share/darwin-identity/install"
}
activate() {
  local generation old versions
  generation=$(readlink -e "$staged" 2>/dev/null) || generation=''
  old=$(readlink -e "$profile" 2>/dev/null) || old=''
  if [[ -z "$generation" ]]; then
    if [[ -z "$old" ]]; then print -u2 -- 'No staged or active release is available.'; return 1; fi
    install_executables "$old" || return
    print -- 'No staged release; the existing release remains active.'
    return
  fi
  if [[ "$generation" == "$old" ]]; then
    update_step 'checking installed agent executables' install_executables "$generation" || return
    print -- 'The staged release is already active.'
    return
  fi
  update_phase='installing coding-agent executables'
  if ! { install_executables "$generation" && nix build --no-link --profile "$profile" "$generation"; }; then
    if [[ -n "$old" ]]; then install_executables "$old"; fi
    print -u2 -- 'Executable installation failed; the active profile is unchanged.'
    return 1
  fi
  print -- 'Release activated for new sessions.'
  versions=$(jq -er '.versions | to_entries | map("\(.key) \(.value)") | join(", ")' "$generation/share/llm-agents/release.json") || return
  update_success="$versions activated for new sessions."
}
if [[ "$activate_only" == true ]]; then
  activate || exit $?
  exit
fi

build_options=(--no-write-lock-file --no-accept-flake-config)
if [[ -n "$checkout" ]]; then
  build_source=$checkout
else
  # Scheduled checks refresh only this maintained input, using installed recipes.
  build_options+=(--refresh --override-input llm-agents "$flake")
fi
mkdir -p "${staged:h}"
previous=$(readlink -e "$staged" 2>/dev/null) || previous=''
update_step 'building and staging coding agents' nix build --print-build-logs --no-link --profile "$staged" "${build_options[@]}" "$build_source#$output" || exit $?
print -- 'Release staged.'
if [[ "$(readlink -e "$staged")" != "$previous" ]]; then
  versions=$(jq -er '.versions | to_entries | map("\(.key) \(.value)") | join(", ")' "$staged/share/llm-agents/release.json")
  update_success="$versions staged."
fi
# Background checks may bootstrap; otherwise ns or the daily job activates.
if [[ "$stage" != true || ( ! -e "$profile" && -z "$checkout" ) ]]; then
  activate || exit $?
fi
