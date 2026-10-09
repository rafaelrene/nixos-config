# Shared Git helpers for standalone commands and interactive shell functions.

git_output() {
  emulate -L zsh
  local directory=$1
  shift
  command git -C "$directory" "$@"
}

# Emit one JSON object per worktree. The -z format keeps unusual paths intact.
git_worktrees() {
  emulate -L zsh
  setopt localoptions pipefail
  local directory=$1 field common configured worktree_path branch head locked list_file tree
  local -a fields
  local -a trees
  local record=''

  list_file=$(mktemp) || return 1
  if ! git_output "$directory" worktree list --porcelain -z > "$list_file"; then
    command rm -f -- "$list_file"
    return 1
  fi
  while IFS= read -r -d $'\0' field; do
    if [[ -z $field ]]; then
      if [[ -n $record ]]; then
        worktree_path=''
        branch=''
        head=''
        locked=false
        for field in "${fields[@]}"; do
          case $field in
            'worktree '*) worktree_path=${field#worktree } ;;
            'branch refs/heads/'*) branch=${field#branch refs/heads/} ;;
            'HEAD '*) head=${field#HEAD } ;;
            locked|locked\ *) locked=true ;;
          esac
        done
        if [[ -n $worktree_path ]]; then
          tree=$(command jq -cn --arg path "$worktree_path" --arg branch "$branch" --arg head "$head" --argjson locked "$locked" '{path:$path,branch:$branch,head:$head,locked:$locked}') || {
            command rm -f -- "$list_file"
            return 1
          }
          trees+=("$tree")
        fi
        fields=()
        record=''
      fi
    else
      fields+=("$field")
      record=1
    fi
  done < "$list_file"
  command rm -f -- "$list_file"

  # Some submodule Git dirs report their internal path as the main worktree.
  common=$(git_output "$directory" rev-parse --path-format=absolute --git-common-dir && print -rn -- $'\0') || return
  common=${common%$'\n\0'}
  configured=$(command git --git-dir "$common" config --get core.worktree 2>/dev/null && print -rn -- $'\0')
  local result=$?
  if (( result == 0 )); then
    configured=${configured%$'\n\0'}
    if [[ $configured == /* ]]; then
      worktree_path=$(command realpath -mz "$configured") || return
    else
      worktree_path=$(command realpath -mz "$common/$configured") || return
    fi
    worktree_path=${worktree_path%$'\0'}
    if (( ${#trees} > 0 )); then
      trees[1]=$(command jq -c --arg path "$worktree_path" '.path=$path' <<<"${trees[1]}") || return
    fi
  elif (( result != 1 )); then
    return $result
  fi

  printf '%s\n' "${trees[@]}"
}
