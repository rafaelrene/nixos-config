set -euo pipefail

default_checkout=$1
skill_updater=$2
targets=$(cat "$3")
shift 3
checkout=${1:-$default_checkout}

update_nodejs_checksums() {
  local manifest="$checkout/modules/applications/nodejs/SHASUMS256.txt" temporary
  temporary=$(mktemp "${manifest}.XXXXXX") || return
  if curl --fail --silent --show-error --location --retry 3 \
    --output "$temporary" https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt \
    && mv -- "$temporary" "$manifest"; then
    return 0
  fi
  rm -f -- "$temporary"
  return 1
}

update_step 'refreshing Node.js checksums' update_nodejs_checksums || exit 2
# Only exit 10 permits a system switch after independent staging failures.
update_step 'refreshing flake inputs' nix flake update --refresh --flake "$checkout" || exit 2
# Keep the upstream skill editable alongside the other live agent settings.
failures=()
if ! update_step 'syncing the frontend-design skill' zsh -f "$skill_updater" "$checkout"; then
  failures+=('frontend-design skill')
fi

agent_updaters=("${(@f)$(jq -r '.agents[]' <<<"$targets")}")
for agent_updater in "${agent_updaters[@]}"; do
  [[ -n "$agent_updater" ]] || continue
  if ! update_step "staging ${agent_updater:t}" "$agent_updater" --stage --flake "$checkout"; then
    failures+=("${agent_updater:t}")
  fi
done
t3_updater=$(jq -r '.t3.stage // empty' <<<"$targets")
if [[ -n "$t3_updater" ]]; then
  if ! update_step 'staging the official T3 nightly' "$t3_updater" --flake "$checkout"; then
    failures+=('T3 Code')
  fi
fi
if (( ${#failures} )); then
  update_failure="Inputs refreshed. Failed: ${(j:, :)failures}. Other independent stages were attempted."
  exit 10
fi
update_success='Inputs refreshed and configured application releases staged.'
