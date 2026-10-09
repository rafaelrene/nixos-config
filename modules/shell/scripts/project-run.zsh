#!/usr/bin/env zsh
set -eu
set -o pipefail

fail() {
  print -u2 -- "$1"
  return 1
}

directory=$PWD:A
if boundary=$(command git rev-parse --show-toplevel 2>/dev/null); then
  boundary=${boundary:A}
else
  boundary=$directory
fi

typeset -a directories records
typeset -A manifests
while true; do
  directories+=("$directory")
  manifest=$directory/package.json
  if [[ -f $manifest ]]; then
    if ! jq -e 'type == "object"' "$manifest" >/dev/null 2>&1; then
      fail "Cannot read $manifest: expected a JSON object."
    fi
    if ! jq -e '(if has("scripts") and .scripts != null then .scripts else {} end) | type == "object" and all(.[]; type == "string")' "$manifest" >/dev/null 2>&1; then
      fail "Cannot read $manifest: scripts must be an object of string commands."
    fi
    if ! jq -e '.packageManager == null or (.packageManager | type == "string")' "$manifest" >/dev/null 2>&1; then
      fail "Cannot read $manifest: packageManager must be a string."
    fi
    manifests[$directory]=$manifest
    location=${directory#${boundary%/}/}
    [[ $directory == $boundary ]] && location=.
    script_entries=$(jq -c '(if has("scripts") and .scripts != null then .scripts else {} end) | to_entries | sort_by(.key)[] | {name:.key,command:.value}' "$manifest") || fail "Cannot read scripts in $manifest."
    while IFS= read -r script_entry; do
      [[ -n $script_entry ]] || continue
      records+=("$(jq -cn --argjson script "$script_entry" --arg directory "$directory" --arg location "$location" --argjson package_index "${#directories}" '{name:$script.name,command:$script.command,directory:$directory,location:$location,package_index:$package_index}')")
    done <<<"$script_entries"
  fi
  [[ $directory == $boundary ]] && break
  parent=${directory:h}
  [[ $parent == $directory ]] && break
  directory=$parent
done

(( ${#records} > 0 )) || fail 'No package.json scripts found in this directory or its repository ancestors.'

input_file=$(mktemp) || fail 'Cannot create the fzf input file.'
selection_file=$(mktemp) || { command rm -f -- "$input_file"; fail 'Cannot create the fzf selection file.'; }
trap 'command rm -f -- "$input_file" "$selection_file"' EXIT

for (( id = 0; id < ${#records}; id++ )); do
  record=${records[$((id + 1))]}
  label=$(jq -r --arg id "$id" 'def clean: explode | map(if . < 32 or . == 127 then 32 else . end) | implode; [$id,.name,.location,.command] | map(clean) | @tsv' <<<"$record")
  printf '%s\0' "$label" >> "$input_file"
done

if fzf --read0 --print0 --delimiter=$'\t' --with-nth=2.. \
  --layout=reverse --wrap --no-multi --no-select-1 --no-exit-0 \
  --prompt='Run > ' --header='Script · package · command | Enter: run · Esc: cancel' \
  < "$input_file" > "$selection_file"; then
  picker_status=0
else
  picker_status=$?
fi
if (( picker_status == 1 || picker_status == 130 )); then
  exit 0
elif (( picker_status != 0 )); then
  fail "fzf failed with status $picker_status."
fi

selected_row=''
if ! IFS= read -r -d $'\0' selected_row < "$selection_file"; then
  if [[ -n $selected_row ]]; then
    fail 'fzf returned a malformed selection.'
  fi
  exit 0
fi
id=${selected_row%%$'\t'*}
if [[ ! $id =~ '^(0|[1-9][0-9]*)$' ]]; then
  fail 'fzf returned an invalid script index.'
fi
max_index=$(( ${#records} - 1 ))
if (( ${#id} > ${#max_index} )); then
  fail 'fzf returned an invalid script index.'
fi
id_value=$(( 10#$id ))
if (( id_value < 0 || id_value > max_index )); then
  fail 'fzf returned an invalid script index.'
fi
record=${records[$((id_value + 1))]}
record_end='__project_run_record_end_8f31c2__'
encoded_name=$(jq -rj --arg end "$record_end" '.name + $end' <<<"$record")
encoded_directory=$(jq -rj --arg end "$record_end" '.directory + $end' <<<"$record")
name=${encoded_name%$record_end}
directory=${encoded_directory%$record_end}
package_index=$(jq -r '.package_index' <<<"$record")

# A manager declaration wins over lockfiles; lock-only workspace ancestors count too.
manager=npm
for (( ancestor = package_index; ancestor <= ${#directories}; ancestor++ )); do
  package_directory=${directories[$ancestor]}
  manifest=${manifests[$package_directory]-}
  if [[ -n $manifest ]]; then
    declared=$(jq -r '.packageManager // empty' "$manifest")
    if [[ -n $declared ]]; then
      manager=${declared%%@*}
      case $manager in npm|pnpm|yarn|bun) ;; *) fail "Unsupported package manager in $manifest: $declared" ;; esac
      break
    fi
  fi
  if [[ -f $package_directory/pnpm-lock.yaml ]]; then manager=pnpm; break
  elif [[ -f $package_directory/yarn.lock ]]; then manager=yarn; break
  elif [[ -f $package_directory/bun.lock || -f $package_directory/bun.lockb ]]; then manager=bun; break
  elif [[ -f $package_directory/package-lock.json || -f $package_directory/npm-shrinkwrap.json ]]; then manager=npm; break
  fi
done

command -v "$manager" >/dev/null 2>&1 || fail "$manager is not on PATH. Enter this project's development environment first."
print -- "$directory> $manager run $(jq -Rn --arg name "$name" '$name')"
command rm -f -- "$input_file" "$selection_file"
input_file=''
selection_file=''
cd -- "$directory"
exec "$manager" run "$name"
