setopt ERR_EXIT NO_UNSET PIPE_FAIL

settings=$(cat "$1")
shift
checkout=$(jq -er '.checkout' <<<"$settings")
hostname=$(jq -er '.hostname' <<<"$settings")
rebuild=$(jq -er '.rebuild' <<<"$settings")
github_auth=$(jq -er '.githubAuth' <<<"$settings")
package_updater=$(jq -er '.packageUpdater' <<<"$settings")
targets_file=$(jq -er '.targetsFile' <<<"$settings")
upgrade=false
checkout_supplied=false
positional=false
for argument in "$@"; do
  if ! $positional; then
    case "$argument" in
      -u|--upgrade-packages) upgrade=true; continue ;;
      -h|--help)
        print -- 'Usage: ns [-u|--upgrade-packages] [checkout]'
        print -- 'Build and switch the system, then activate staged coding agents and T3.'
        print -- 'With -u, refresh inputs and stage the newest official T3 nightly first.'
        exit 0 ;;
      --) positional=true; continue ;;
      -*) print -u2 -- "Unknown option: $argument"; exit 2 ;;
    esac
  fi
  if $checkout_supplied || [[ -z "$argument" ]]; then
    print -u2 -- 'Supply at most one nonempty checkout path.'
    exit 2
  fi
  checkout=$argument
  checkout_supplied=true
done
checkout=${checkout:A}

failures=()
if $upgrade; then
  if update_step 'refreshing inputs and staging releases' "$package_updater" "$checkout"; then
    :
  else
    code=$?
    # All other errors stop the switch, including failed input refreshes and logging.
    if (( code != 10 )); then exit "$code"; fi
    failures+=('package staging')
  fi
fi

update_step 'building and switching the system' "$github_auth" sudo --preserve-env=NIX_CONFIG "$rebuild" switch --flake "$checkout#$hostname" || exit $?
# Read the applied configuration so removed features are not activated by an old ns.
update_phase='reading the applied update commands'
targets=$(cat "$targets_file")
agent_updaters=("${(@f)$(jq -r '.agents[]' <<<"$targets")}")
for agent_updater in "${agent_updaters[@]}"; do
  [[ -n "$agent_updater" ]] || continue
  if ! update_step "activating ${agent_updater:t}" "$agent_updater" --activate; then
    failures+=("${agent_updater:t} activation")
  fi
done
t3_activator=$(jq -r '.t3.activate // empty' <<<"$targets")
if [[ -n "$t3_activator" ]]; then
  if ! update_step 'activating T3 Code' "$t3_activator"; then
    failures+=('T3 activation')
  fi
fi
if (( ${#failures} )); then
  update_failure="System applied. Failed steps: ${(j:, :)failures}. Each updater reports its own result above."
  exit 1
fi
update_success='System applied. All configured application activations succeeded.'
