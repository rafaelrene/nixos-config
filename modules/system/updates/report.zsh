# Run the command in a child so tee preserves its full output and exit status.
setopt NO_UNSET PIPE_FAIL
if [[ ${1-} != --run ]]; then
  log=$2
  umask 077
  if ! mkdir -p -- "${log:h}"; then
    print -u2 -- "ERROR: $1 could not create its log directory: ${log:h}"
    "$3" "$1" error "Cannot create the update log: $log" || true
    exit 1
  fi
  zsh -f "$0" --run "$@" 2>&1 | tee -a -- "$log"
  results=("${pipestatus[@]}")
  if (( results[2] != 0 )); then
    print -u2 -- "ERROR: $1 could not save its output to $log"
    "$3" "$1" error "Cannot save update output: $log" || true
    exit 1
  fi
  exit "$results[1]"
fi
shift
update_title=$1
update_log=$2
update_notify=$3
update_script=$4
shift 4
update_phase=initialization
update_success=''
update_failure=''
update_notifications=${NIX_UPDATE_NOTIFY:-true}

update_step() {
  update_phase=$1
  shift
  print -- "$update_title: $update_phase..."
  "$@"
}

TRAPEXIT() {
  local result=$? outcome=success message
  # zsh also runs EXIT traps in command substitutions; keep their stdout intact.
  (( ZSH_SUBSHELL == 0 )) || return "$result"
  if (( result != 0 )); then
    outcome=error
    message=${update_failure:-"Step failed: $update_phase (exit $result)."}
    print -u2 -- "ERROR: $update_title: $message"
    print -u2 -- "Log: $update_log"
  else
    message=${update_success:-Completed without changes.}
    print -- "$update_title: $message"
  fi
  if [[ "$update_notifications" == true && ( "$outcome" == error || -n "$update_success" ) ]]; then
    if ! "$update_notify" "$update_title" "$outcome" "$message Log: $update_log"; then
      print -u2 -- "WARNING: $update_title could not deliver its $outcome notification."
    fi
  fi
  return "$result"
}
print -- "$(date '+%Y-%m-%d %H:%M:%S %Z') $update_title started."
source "$update_script" "$@"
