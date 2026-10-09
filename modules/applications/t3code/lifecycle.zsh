setopt NO_UNSET PIPE_FAIL

settings_file=$1
action=$2
shift 2
if [[ "$action" == --help || "$action" == -h ]]; then
  print -- 'Usage: t3-lifecycle <stage GENERATION | seed | request | request-rollback | stop-clients | ready | activate | rollback | launch [ARGS...]>'
  exit 0
fi
settings=$(cat "$settings_file") || exit
for key in state profile staged previous desktopApp desktopCommand spawn notifyCommand serviceCommand serviceFile healthUrl initial darwin processCommand; do
  value=$(jq -r --arg key "$key" '.[$key] // empty' <<<"$settings") || exit
  typeset "$key=$value"
done
# jq's // also treats false as absent.
settings_home=$(jq -er '.home' <<<"$settings") || exit
darwin=$(jq -r '.darwin | tostring' <<<"$settings") || exit
failure=''
fail() {
  failure=$1
  print -u2 -r -- "$failure"
  return 1
}
run() {
  "$@" || { fail "Command failed: $*"; return 1; }
}
generation() {
  if [[ -e "$1" ]]; then readlink -f "$1"; fi
}
active() {
  local target
  target=$(generation "$profile") || return
  print -r -- "${target:-$initial}"
}

# Read process names and arguments separately because executable names may contain
# spaces. A process disappearing between snapshots is simply omitted.
desktop_processes() {
  local names arguments uid
  uid=$(id -u) || return
  names=$("$processCommand" -wwaxo pid=,ppid=,uid=,comm=) || return
  arguments=$("$processCommand" -wwaxo pid=,args=) || return
  jq -cn --arg names "$names" --arg arguments "$arguments" --argjson uid "$uid" \
    --arg profile "$profile" --arg app "$desktopApp" --arg retained "$settings_home/Applications/.T3 Code.next.app" --argjson darwin "$darwin" '
    ($arguments | split("\n") | map(try capture("^\\s*(?<pid>[0-9]+)\\s+(?<command>.*)$") catch empty)
      | map({key: .pid, value: .command}) | from_entries) as $commands |
    [$names | split("\n")[] | try capture("^\\s*(?<pid>[0-9]+)\\s+(?<ppid>[0-9]+)\\s+(?<uid>[0-9]+)\\s+(?<name>.*)$") catch empty |
      .command = $commands[.pid] | .pid |= tonumber | .ppid |= tonumber | .uid |= tonumber |
      select(.uid == $uid and .command != null) |
      (.name | split("/") | last) as $name |
      select(($name | test("^T3 Code \\(")) or $name == "t3code" or $name == "t3code-desktop") |
      select((.command | test("^/nix/store/[^/]+-t3code-desktop[^/]*/")) or
        (.command | startswith($profile + "/")) or
        ($darwin and ((.command | startswith($app + "/Contents/")) or
          (.command | startswith($retained + "/Contents/")))))]'
}
desktops() {
  desktop_processes | jq '[.[] | select(.command | contains(" --type=") | not)] | . as $clients | [.[] | select(.ppid as $parent | $clients | any(.pid == $parent) | not)]'
}
desktop_current() {
  local pid=$1 target=$2 result version mapped
  if [[ "$darwin" == true ]]; then
    result=$("$desktopCommand" "$settings_file" process-current "$target" "$pid") || return 1
    [[ "$result" == true ]]
  else
    version=$(jq -er '.version' "$target/share/t3code/release.json") || return 1
    mapped=$(lsof -a -p "$pid" -d txt -Fn) || return 1
    print -r -- "$mapped" | jq -Rse --arg version "$version" 'split("\n") | any(startswith("n/nix/store/") and (contains("-t3code-desktop-" + $version + "/") or contains("-t3code-desktop-" + $version + "-extracted/")))' >/dev/null
  fi
}
server_pid() {
  local result
  if [[ "$darwin" == true ]]; then
    result=$("$serviceCommand" list org.nixos.t3code) || return 1
    print -r -- "$result" | jq -Rsr 'try capture("\"PID\" = (?<pid>[0-9]+);").pid catch "0"'
  else
    "$serviceCommand" --user show t3code.service --property MainPID --value
  fi
}
healthy() {
  local target=$1 running pid listener descriptor version
  running=$(cat "$state/running.json" 2>/dev/null) || return 1
  pid=$(server_pid) || return 1
  jq -e --arg generation "$target" --arg pid "$pid" '.generation == $generation and (.pid | tostring) == $pid' <<<"$running" >/dev/null || return 1
  listener=$(lsof -nP -a -p "$pid" -iTCP:3773 -sTCP:LISTEN -t) || return 1
  [[ "$listener" == "$pid" ]] || return 1
  descriptor=$(curl --fail --silent --max-time 2 "$healthUrl") || return 1
  version=$(jq -er '.version' "$target/share/t3code/release.json") || return 1
  jq -e --arg version "$version" '.serverVersion == $version' <<<"$descriptor" >/dev/null
}
wait_ready() {
  local target=${1-} attempts=${2:-30} expected attempt
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    expected=$target
    if [[ -z "$expected" ]]; then expected=$(active) || return; fi
    if [[ -n "$expected" ]] && healthy "$expected"; then return; fi
    sleep 1 || return
  done
  fail 'T3 Code did not become ready. The desktop stays closed; inspect the server logs before retrying t3-activate.'
}
wait_stopped() {
  local service=$1 pid=$2 result code attempt
  for ((attempt = 1; attempt <= 30; attempt++)); do
    result=$("$serviceCommand" print "$service" 2>&1)
    code=$?
    if ((code == 113)) && { [[ -z "$pid" || "$pid" == 0 ]] || ! kill -0 "$pid" 2>/dev/null; }; then return; fi
    if ((code != 0 && code != 113)); then fail "Cannot inspect the stopping T3 Code service: $result"; return; fi
    sleep 1 || return
  done
  fail 'T3 Code did not stop. The active profile is unchanged; inspect the server logs before retrying t3-activate.'
}
request() {
  local rollback=$1 name=t3code-restart service result pid exit_status attempt
  [[ "$rollback" != true ]] || name=t3code-rollback
  print -- 'T3 Code: waiting for coordinated activation...'
  if [[ "$darwin" == true ]]; then
    service="gui/$(id -u)/org.nixos.$name"
    run "$serviceCommand" kickstart -p "$service" >/dev/null || return
    for ((attempt = 1; attempt <= 240; attempt++)); do
      result=$("$serviceCommand" list "org.nixos.$name" 2>&1) || { fail "Cannot inspect T3 Code activation: $result"; return; }
      pid=$(print -r -- "$result" | jq -Rsr 'try capture("\"PID\" = (?<pid>[0-9]+);").pid catch ""') || return
      if [[ -z "$pid" ]]; then
        exit_status=$(print -r -- "$result" | jq -Rser 'capture("\"LastExitStatus\" = (?<code>-?[0-9]+);").code') || return
        if [[ "$exit_status" != 0 ]]; then fail "T3 Code activation failed. See $settings_home/.local/state/nix-darwin/t3code-activation.log."; return; fi
        print -- 'T3 Code: activation completed.'
        return
      fi
      sleep 1 || return
    done
    fail 'T3 Code activation is still running after four minutes. Inspect the activation log.'
  else
    run "$serviceCommand" --user start "$name.service" || return
    print -- 'T3 Code: activation completed.'
  fi
}
launch() {
  local target existing clients pid attempt
  target=$(active) || return
  if [[ -z "$target" ]] || ! healthy "$target"; then fail "T3 Code's active server is not ready. Run t3-activate, then reopen the desktop."; return; fi
  existing=$(desktops) || return
  if (( $(jq 'length' <<<"$existing") > 1 )); then fail 'An outdated or duplicate T3 Code desktop is running. Run t3-activate to replace it.'; return; fi
  for pid in ${(f)"$(jq -r '.[].pid' <<<"$existing")"}; do
    if ! desktop_current "$pid" "$target"; then fail 'An outdated or duplicate T3 Code desktop is running. Run t3-activate to replace it.'; return; fi
  done
  run "$spawn" "$@" || return
  for ((attempt = 1; attempt <= 30; attempt++)); do
    clients=$(desktops) || return
    if [[ "$(jq 'length' <<<"$clients")" == 1 ]] && desktop_current "$(jq -r '.[0].pid' <<<"$clients")" "$target"; then return; fi
    sleep 1 || return
  done
  fail "T3 Code desktop did not start. See $state/desktop.log."
}
retained_processes() {
  desktop_processes | jq --argjson original "$1" '[.[] | select(.pid as $pid | $original | any(.pid == $pid))]'
}
stop_desktops() {
  local original=$1 current remaining pid attempt
  print -u2 -- 'T3 Code: closing desktop clients...'
  current=$(retained_processes "$original") || return
  # Main clients shut down their workers before any survivors are forced closed.
  for pid in ${(f)"$(jq -r '. as $clients | .[] | select(.ppid as $parent | $clients | any(.pid == $parent) | not) | .pid' <<<"$current")"}; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  for ((attempt = 1; attempt <= 5; attempt++)); do
    remaining=$(retained_processes "$original") || return
    [[ "$remaining" != '[]' ]] || return 0
    sleep 1 || return
  done
  # Recheck ownership before signalling a PID that may have been reused.
  remaining=$(retained_processes "$original") || return
  if [[ "$remaining" != '[]' ]]; then
    print -u2 -- 'T3 Code: force-stopping unresponsive desktop processes...'
    for pid in ${(f)"$(jq -r '.[].pid' <<<"$remaining")"}; do kill -KILL "$pid" 2>/dev/null || true; done
  fi
  for ((attempt = 1; attempt <= 5; attempt++)); do
    remaining=$(retained_processes "$original") || return
    [[ "$remaining" != '[]' ]] || return 0
    sleep 1 || return
  done
  fail 'T3 Code desktop did not quit. Activation stopped before changing the server.'
}
# Every journal write reaches disk before its corresponding mutation.
save_state() {
  local file="$state/$1" temporary="$state/$1.tmp"
  print -r -- "$2" >"$temporary" || return
  run sync "$temporary" || return
  run mv -f "$temporary" "$file" || return
  run sync "$state"
}
clear_journal() {
  run rm -f "$state/activation.json" || return
  run sync "$state"
}
desktop_action() {
  if [[ "$darwin" == true ]]; then run "$desktopCommand" "$settings_file" "$1" "$2"; fi
}
app_current() {
  [[ "$darwin" == true ]] || return 0
  local result
  result=$("$desktopCommand" "$settings_file" current "$1") || return 1
  [[ "$result" == true ]]
}
stop_server() {
  local domain pid result code
  if [[ "$darwin" == true ]]; then
    domain="gui/$(id -u)"
    pid=$(server_pid) || pid=''
    result=$("$serviceCommand" print "$domain/org.nixos.t3code" 2>&1)
    code=$?
    if ((code == 0)); then run "$serviceCommand" bootout "$domain/org.nixos.t3code" || return; fi
    wait_stopped "$domain/org.nixos.t3code" "$pid"
  else
    run "$serviceCommand" --user stop t3code.service
  fi
}
start_server() {
  if [[ "$darwin" == true ]]; then
    run "$serviceCommand" bootstrap "gui/$(id -u)" "$serviceFile"
  else
    run "$serviceCommand" --user start t3code.service
  fi
}
recover() {
  local journal old target reopen processes
  journal=$(cat "$state/activation.json") || return
  old=$(jq -er '.previous' <<<"$journal") || return
  target=$(jq -er '.target' <<<"$journal") || return
  reopen=$(jq -r '.reopen' <<<"$journal") || return
  print -- 'T3 Code: restoring the previous release after an incomplete activation...'
  # Retain the journal until the old server and complete desktop both work.
  desktop_action prepare "$old" || return
  processes=$(desktop_processes) || return
  stop_desktops "$processes" || return
  stop_server || return
  run nix-env --profile "$profile" --set "$old" || return
  desktop_action install "$old" || return
  start_server || return
  wait_ready "$old" || return
  desktop_action dock "$old" || return
  if [[ "$reopen" == true ]]; then launch || return; fi
  run nix-env --profile "$staged" --set "$old" || return
  if [[ "$target" != "$old" ]]; then save_state blocked.json "$(jq -cn --arg target "$target" '$target')" || return; fi
  clear_journal || return
  print -- 'T3 Code: the previous release is running. Database files were left untouched.'
}
promote() {
  local target=$1 old=$2 rollback=$3 processes=$4 reopen=$5 remaining
  stop_desktops "$processes" || return
  remaining=$(desktop_processes) || return
  if [[ "$remaining" != '[]' ]]; then fail 'A T3 Code desktop appeared during shutdown.'; return; fi
  print -- 'T3 Code: stopping the managed server...'
  stop_server || return
  run nix-env --profile "$profile" --set "$target" || return
  desktop_action install "$target" || return
  start_server || return
  wait_ready "$target" || return
  desktop_action dock "$target" || return
  if [[ "$reopen" == true ]]; then launch || return; fi
  if [[ "$rollback" == true ]]; then
    run nix-env --profile "$staged" --set "$target" || return
    if [[ "$old" != "$target" ]]; then save_state blocked.json "$(jq -cn --arg target "$old" '$target')" || return; fi
  fi
  clear_journal
}
activate() {
  local rollback=$1 old target blocked processes clients clients_current=true pid reopen=false activation_failure
  old=$(active) || return
  if [[ "$rollback" == true ]]; then target=$(generation "$previous") || return
  else target=$(generation "$staged") || return; target=${target:-$old}; fi
  if [[ -z "$target" ]]; then fail 'No T3 Code release is available for this operation.'; return; fi
  blocked=$(jq -r '.' "$state/blocked.json" 2>/dev/null) || blocked=''
  if [[ "$target" == "$blocked" ]]; then fail 'This T3 Code generation failed or was rolled back. Stage a different release before activating it.'; return; fi
  processes=$(desktop_processes) || return
  clients=$(desktops) || return
  if [[ "$processes" != '[]' ]]; then
    if [[ "$(jq 'length' <<<"$clients")" != 1 ]]; then clients_current=false
    elif ! desktop_current "$(jq -r '.[0].pid' <<<"$clients")" "$target"; then clients_current=false; fi
  fi
  if [[ "$old" == "$target" && "$clients_current" == true ]] && healthy "$target" && app_current "$target"; then
    desktop_action dock "$target" || return
    print -- 'T3 Code: the active server and desktop are current.'
    return
  fi
  if [[ -z "$old" ]]; then fail 'No previous T3 Code release exists. Bootstrap it before activation.'; return; fi
  # Verify the replacement and retain a GC root before interrupting the old app.
  desktop_action prepare "$target" || return
  if [[ "$target" != "$old" ]]; then run nix-env --profile "$previous" --set "$old" || return; fi
  [[ "$clients" == '[]' ]] || reopen=true
  save_state activation.json "$(jq -cn --arg previous "$old" --arg target "$target" --argjson reopen "$reopen" '{previous: $previous, target: $target, reopen: $reopen}')" || return
  if ! promote "$target" "$old" "$rollback" "$processes" "$reopen"; then
    activation_failure=${failure:-'A lifecycle command failed'}
    if ! recover; then fail "Activation failed: $activation_failure. Recovery also failed: ${failure:-A lifecycle command failed}. The previous release and recovery journal are retained; retry t3-activate."; return; fi
    fail "Activation failed: $activation_failure. The previous release was restored."
    return
  fi
  local version
  version=$(jq -er '.version' "$target/share/t3code/release.json") || return
  print -- "T3 Code: activated $version."
}
perform() {
  local target blocked processes reopen
  case "$action" in
    stage)
      target=${1:?A release generation is required}
      blocked=$(jq -r '.' "$state/blocked.json" 2>/dev/null) || blocked=''
      if [[ "$target" == "$blocked" ]]; then fail 'This T3 Code generation failed or was rolled back; leaving the working release installed.'; return; fi
      run nix-env --profile "$staged" --set "$target"
      ;;
    seed)
      target=$(generation "$profile") || return
      if [[ -z "$target" ]]; then
        target=$(generation "$staged") || return
        target=${target:-$initial}
        if [[ -z "$target" ]]; then fail 'No T3 Code bootstrap release is available.'; return; fi
        run nix-env --profile "$profile" --set "$target" || return
      fi
      ;;
    request) request false ;;
    request-rollback) request true ;;
    stop-clients)
      processes=$(desktops) || return
      reopen=false
      [[ "$processes" == '[]' ]] || reopen=true
      processes=$(desktop_processes) || return
      stop_desktops "$processes" || return
      processes=$(desktop_processes) || return
      if [[ "$processes" != '[]' ]]; then fail 'A T3 Code desktop appeared during shutdown. Server startup stopped.'; return; fi
      print -- "$reopen"
      ;;
    ready) wait_ready '' 120 ;;
    activate|rollback|launch)
      if [[ -e "$state/activation.json" ]]; then recover || return; fi
      case "$action" in
        launch) launch "$@" ;;
        activate) activate false ;;
        rollback) activate true ;;
      esac
      ;;
    *) fail "Unknown T3 Code lifecycle action: $action" ;;
  esac
}
run mkdir -p "${profile:h}" || exit
if ! perform "$@"; then
  if [[ "$action" == activate || "$action" == rollback || "$action" == launch ]]; then
    message="T3 Code: ${failure:-A lifecycle command failed.}"
    log=activation.log
    [[ "$action" != launch ]] || log=desktop.log
    print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $message" >>"$state/$log"
    "$notifyCommand" "$message" >/dev/null 2>&1 || true
  fi
  exit 1
fi
