setopt ERR_EXIT NO_UNSET PIPE_FAIL

settings_file=$1
shift
settings=$(cat "$settings_file")
profile=$(jq -er '.profile' <<<"$settings")
staged=$(jq -er '.staged' <<<"$settings")
bundle=$(jq -er '.bundle' <<<"$settings")
flake=$(jq -er '.flake' <<<"$settings")
darwin=$(jq -r '.darwin // false | tostring' <<<"$settings")
stage=false
activate_only=false
migrate_only=false
for argument in "$@"; do
  case "$argument" in
    --help|-h) print -- "Usage: update-llm-agents [--stage | --activate | --migrate]"; exit 0 ;;
    --stage) stage=true ;;
    --activate) activate_only=true ;;
    --migrate) migrate_only=true ;;
    *) print -u2 -- "Unknown option: $argument"; exit 1 ;;
  esac
done
if [[ "$stage" == true && "$activate_only" == true ||
  "$migrate_only" == true && ( "$stage" == true || "$activate_only" == true ) ]]; then
  print -u2 -- 'Use only one of --stage, --activate, or --migrate.'
  exit 1
fi

fetch() {
  curl --fail --silent --show-error --max-time 60 --header 'Cache-Control: no-cache' "$1"
}
stable_version() {
  if [[ ! "$1" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 -- "Invalid stable release version: $1"
    return 1
  fi
  print -r -- "$1"
}
checksum() {
  if [[ ! "$1" =~ '^[a-f0-9]{64}$' ]]; then
    print -u2 -- 'Missing or invalid publisher SHA-256 checksum.'
    return 1
  fi
  print -r -- "$1"
}
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

print -- "Agent tools: checking the publishers' latest stable releases..."
codex=$(fetch https://releases.openai.com/codex/channels/latest)
codex_tag=$(jq -er '.tag_name | select(type == "string")' <<<"$codex")
codex_version=$(stable_version "${codex_tag#rust-v}")
codex_darwin=$(checksum "$(jq -er '[.assets[] | select(.name == "codex-package-aarch64-apple-darwin.tar.gz")] | select(length == 1) | .[0].digest | select(type == "string") | sub("^sha256:"; "")' <<<"$codex")")
codex_linux=$(checksum "$(jq -er '[.assets[] | select(.name == "codex-package-x86_64-unknown-linux-musl.tar.gz")] | select(length == 1) | .[0].digest | select(type == "string") | sub("^sha256:"; "")' <<<"$codex")")
claude_base=https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
claude_latest=$(fetch "$claude_base/latest")
claude_version=$(stable_version "$(print -r -- "$claude_latest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
claude=$(fetch "$claude_base/$claude_version/manifest.json")
if ! jq -e --arg version "$claude_version" '.version == $version' <<<"$claude" >/dev/null; then
  print -u2 -- 'Claude release manifest does not match its latest version.'
  exit 1
fi
claude_darwin=$(checksum "$(jq -er '.platforms["darwin-arm64"].checksum | select(type == "string")' <<<"$claude")")
claude_linux=$(checksum "$(jq -er '.platforms["linux-x64"].checksum | select(type == "string")' <<<"$claude")")
releases=$(jq -cn --arg codex "$codex_version" --arg cd "$codex_darwin" --arg cl "$codex_linux" \
  --arg claude "$claude_version" --arg ad "$claude_darwin" --arg al "$claude_linux" \
  '{codex: {version: $codex, hashes: {"aarch64-darwin": $cd, "x86_64-linux": $cl}}, "claude-code": {version: $claude, hashes: {"aarch64-darwin": $ad, "x86_64-linux": $al}}}')
print -- "Agent tools: Codex $codex_version, Claude Code $claude_version."
# Numtide still supplies OpenCode and Claude's platform integration.
source=$(nix flake prefetch --refresh --json --no-accept-flake-config "$flake")
store_path=$(jq -er '.storePath | select(type == "string")' <<<"$source")
source_hash=$(jq -er '.hash | select(type == "string")' <<<"$source")
if [[ ! "$store_path" =~ '^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._=-]+$' || ! "$source_hash" =~ '^sha256-[A-Za-z0-9+/]{43}=$' ]]; then
  print -u2 -- 'Invalid prefetched agent source.'
  exit 1
fi
# Release values contain only validated versions and hex checksums.
identity=''
if [[ "$darwin" == true ]]; then identity="profile = $(jq -Rn --arg profile "$profile" '$profile' | sed 's/\${/\\${/g');"; fi
expression="$bundle { path = \"$store_path\"; hash = \"$source_hash\"; releases = builtins.fromJSON ''$releases''; $identity }"
expected=$(nix eval --raw --expr "($expression).outPath")
if [[ "$expected" != "$(resolved "$staged")" ]]; then
  print -- 'Agent tools: building Codex, Claude Code and OpenCode...'
  generation=$(nix build --print-build-logs --no-link --print-out-paths --expr "$expression")
  mkdir -p "${staged:h}"
  nix-env --profile "$staged" --set "$generation"
  print -- 'Agent tools: staged.'
else
  print -- 'Agent tools: already staged.'
fi
# Bootstrap a missing profile; background checks otherwise only stage.
if [[ "$stage" != true || ! -e "$profile" ]]; then
  activate
fi
