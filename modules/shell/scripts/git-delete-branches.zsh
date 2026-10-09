#!/usr/bin/env zsh
set -eu
set -o pipefail

source ${0:A:h}/git-worktrees.zsh

fail() {
  print -u2 -r -- "$1"
  return 1
}

# Consume complete command output before testing it. grep -q in a producer
# pipeline can turn SIGPIPE into a false "merged" result under pipefail.
is_merged() {
  local head=$1 base=$2 fork merges cherry patch merged
  git merge-base --is-ancestor "$head" "$base" && return 0
  fork=$(git merge-base "$base" "$head" 2>/dev/null) || return 1
  merges=$(git rev-list --merges "$base..$head") || return 1
  if [[ -z $merges ]]; then
    cherry=$(git cherry "$base" "$head") || return 1
    if ! grep -q '^+' <<<"$cherry"; then return 0; fi
  fi
  patch=$(git diff --no-ext-diff --no-textconv --binary "$fork" "$head" | git patch-id --stable | awk '{print $1}') || return 1
  [[ -n $patch ]] || return 0
  merged=$(git log --no-ext-diff --no-textconv --no-merges --pretty=format:%H -p --binary "$fork..$base" | git patch-id --stable | awk '{print $1}') || return 1
  grep -Fxq -- "$patch" <<<"$merged"
}

require_clean() {
  local directory=$1 changes
  changes=$(git_output "$directory" status --porcelain --untracked-files=all --ignore-submodules=none 2>&1) || {
    fail "Cannot inspect worktree $(jq -Rn --arg path "$directory" '$path'): $changes"
    return 1
  }
  if [[ -n $changes ]]; then
    fail "Uncommitted changes in $(jq -Rn --arg path "$directory" '$path'); commit or save them first."
    return 1
  fi
}

# Git needs --force for initialized submodules, even when they are clean.
# Check every repository and archived private history before allowing that flag.
removal_options() {
  local directory=$1 gitdir private_modules module repository output module_file find_file
  local -a repositories
  local has_modules=false
  require_clean "$directory" || return
  module_file=$(mktemp) || { fail 'Cannot inspect submodule worktrees.'; return 1; }
  if ! git_output "$directory" submodule foreach --quiet --recursive 'printf "%s\0" "$toplevel/$sm_path"' >"$module_file"; then
    command rm -f -- "$module_file"
    fail 'Cannot inspect submodule worktrees.'
    return 1
  fi
  while IFS= read -r -d $'\0' module; do
    has_modules=true
    if ! require_clean "$module"; then command rm -f -- "$module_file"; return 1; fi
    repository=$(git_output "$module" rev-parse --absolute-git-dir && print -rn -- $'\0') || {
      command rm -f -- "$module_file"
      fail "Cannot inspect submodule repository $(jq -Rn --arg path "$module" '$path')."
      return 1
    }
    repository=${repository%$'\n\0'}
    repositories+=("$repository")
  done <"$module_file"
  command rm -f -- "$module_file"
  gitdir=$(git_output "$directory" rev-parse --absolute-git-dir && print -rn -- $'\0') || { fail 'Cannot inspect the worktree Git directory.'; return 1; }
  gitdir=${gitdir%$'\n\0'}
  private_modules=$gitdir/modules
  if [[ -d $private_modules ]]; then
    has_modules=true
    find_file=$(mktemp) || { fail 'Cannot inspect private submodule repositories.'; return 1; }
    if ! find "$private_modules" -type f -name config -print0 >"$find_file"; then
      command rm -f -- "$find_file"
      fail 'Cannot inspect private submodule repositories.'
      return 1
    fi
    while IFS= read -r -d $'\0' repository; do repositories+=("${repository:h}"); done <"$find_file"
    command rm -f -- "$find_file"
  fi
  for repository in "${(@u)repositories}"; do
    output=$(git_output "$directory" --git-dir "$repository" for-each-ref --format='%(refname)' refs/stash) || {
      fail "Cannot inspect stashes in $(jq -Rn --arg path "$repository" '$path')."
      return 1
    }
    if [[ -n $output ]]; then
      fail "Submodule repository $(jq -Rn --arg path "$repository" '$path') has a stash; preserve it before deleting."
      return 1
    fi
    output=$(git_output "$directory" --git-dir "$repository" rev-list --max-count=1 HEAD --all --reflog --not --remotes) || {
      fail "Cannot inspect history in $(jq -Rn --arg path "$repository" '$path')."
      return 1
    }
    if [[ -n $output ]]; then
      fail "Submodule repository $(jq -Rn --arg path "$repository" '$path') has history outside recorded remote branches; preserve it or fetch its remote before retrying."
      return 1
    fi
  done
  if [[ $has_modules == true ]]; then print -- --force; fi
}

inside=$(git rev-parse --is-inside-work-tree 2>/dev/null) || fail 'Not in a git repo!'
[[ $inside == true ]] || fail 'Not in a git repo!'
root=$(git rev-parse --show-toplevel && print -rn -- $'\0')
root=${root%$'\n\0'}
root=${root:A}
devenv_root=${DEVENV_ROOT:-}
[[ -z $devenv_root ]] || devenv_root=${devenv_root:A}
trees=$(git_worktrees "$root")
main_tree=${trees%%$'\n'*}
main_path=$(jq -jr '.path + "\u0000"' <<<"$main_tree")
main_path=${main_path%$'\0'}
main_branch=$(jq -r '.branch' <<<"$main_tree")
current_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
base=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
default_branch=${base#refs/remotes/origin/}
if [[ -z $default_branch ]]; then
  for branch in main master "$main_branch"; do
    if [[ -n $branch ]] && git show-ref --verify --quiet "refs/heads/$branch"; then
      default_branch=$branch
      base=refs/heads/$branch
      break
    fi
  done
fi
[[ -n $base ]] || base=HEAD
git rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || fail "Cannot resolve $base to compare branches."

typeset -a rows
add_candidate() {
  local branch=$1 head=$2 worktree_path=$3 locked=$4 reason='' removal_result state
  if [[ -n $worktree_path && ( $worktree_path == "$root" || $worktree_path == "$main_path" ) ]]; then return 0; fi
  if [[ -n $devenv_root && -n $worktree_path && ( $devenv_root == "$worktree_path" || $devenv_root == "$worktree_path/"* ) ]]; then
    print -u2 -- "Keeping active devenv worktree: $(jq -Rn --arg path "$worktree_path" '$path') (exit devenv before deleting it)."
    return 0
  fi
  if [[ $locked == true ]]; then reason='Worktree is locked.'
  elif [[ -n $worktree_path ]]; then
    if ! removal_result=$(removal_options "$worktree_path" 2>&1); then reason=$removal_result; fi
  fi
  if [[ $locked == true ]]; then state=LOCKED
  elif [[ -n $reason ]]; then
    if [[ $reason == 'Uncommitted changes'* ]]; then state=DIRTY; else state=BLOCKED; fi
  elif is_merged "$head" "$base"; then state=merged
  else state=UNMERGED; reason='Commits are not merged into the default reference.'
  fi
  rows+=("$(jq -cn --arg branch "$branch" --arg head "$head" --arg path "$worktree_path" --arg reason "$reason" --arg state "$state" --argjson locked "$locked" '{branch:$branch,head:$head,path:$path,reason:$reason,state:$state,locked:$locked,force:false}')")
}
branch_file=$(mktemp)
if ! git for-each-ref --format='%(refname:strip=2)%09%(objectname)' refs/heads/ >"$branch_file"; then command rm -f -- "$branch_file"; fail 'Cannot list branches.'; fi
while IFS=$'\t' read -r branch head; do
  [[ -n $branch ]] || continue
  [[ $branch == "$current_branch" || $branch == "$default_branch" || $branch == "$main_branch" ]] && continue
  tree=$(jq -cs --arg branch "$branch" 'map(select(.branch == $branch))[0] // empty' <<<"$trees")
  worktree_path=''
  locked=false
  if [[ -n $tree ]]; then
    worktree_path=$(jq -jr '.path + "\u0000"' <<<"$tree")
    worktree_path=${worktree_path%$'\0'}
    locked=$(jq -r '.locked' <<<"$tree")
  fi
  add_candidate "$branch" "$head" "$worktree_path" "$locked"
done <"$branch_file"
command rm -f -- "$branch_file"
while IFS= read -r tree; do
  [[ -n $tree ]] || continue
  branch=$(jq -r '.branch' <<<"$tree")
  [[ -z $branch ]] || continue
  worktree_path=$(jq -jr '.path + "\u0000"' <<<"$tree")
  worktree_path=${worktree_path%$'\0'}
  add_candidate '' "$(jq -r '.head' <<<"$tree")" "$worktree_path" "$(jq -r '.locked' <<<"$tree")"
done <<<"$trees"
(( ${#rows} > 0 )) || { print 'No branches or worktrees to delete.'; exit 0; }

# Restore all selected IDs, including rows hidden by the query, on every redraw.
typeset -a selected_ids fields required_ids labels
for (( id=0; id<${#rows}; id++ )); do
  [[ $(jq -r .reason <<<"${rows[$((id+1))]}") == '' ]] && selected_ids+=("$id")
done
query=''
focus=0
while true; do
  labels=()
  for (( id=0; id<${#rows}; id++ )); do
    row=${rows[$((id+1))]}
    label=$(jq -r '((if .force then "[FORCE] " else "" end) + (if .branch == "" then "(detached " + .head[0:8] + ")" else .branch end) + " [" + .state + "]" + (if .path == "" then "" else "  worktree: " + (.path | tojson) end) + (if .reason == "" then "" else "  " + .reason end)) | gsub("[\u0000-\u001f\u007f]"; " ")' <<<"$row")
    labels+=("$id"$'\t'"$label")
  done
  restore=''
  for id in "${selected_ids[@]}"; do restore+="pos($((id+1)))+select+"; done
  restore+="pos($((focus+1)))"
  picker_status=0
  output=$(printf '%s\0' "${labels[@]}" | env FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' GIT_DB_QUERY="$query" \
    fzf --multi --sync --read0 --print0 --print-query --layout=reverse --track \
      --delimiter=$'\t' --with-nth=2.. --with-shell 'bash -c' --prompt 'Delete> ' \
      --header="Tab cycle state | Shift-Tab reverse | Ctrl-F force required | Ctrl-A all | Ctrl-D clear | Enter review | Esc cancel
States: unselected > selected > FORCE. Arrows move. Search keeps hidden selections.
FORCE discards changes, locks and submodule history. UNMERGED compares with $base." \
      --bind="load:clear-selection+$restore+transform-query(printf '%s' \"\$GIT_DB_QUERY\")+end-of-line" \
      --bind='tab:transform:id={1}; if [ -n "$id" ]; then printf "print(next:%s:%s)+accept" "$id" "$FZF_SELECT_COUNT"; fi' \
      --bind='btab:transform:id={1}; if [ -n "$id" ]; then printf "print(previous:%s:%s)+accept" "$id" "$FZF_SELECT_COUNT"; fi' \
      --bind='ctrl-d:print(clear)+accept,esc:abort' --bind='ctrl-a:print(all)+accept' \
      --bind='ctrl-f:transform:id={1}; printf "print(force:%s:%s)+accept" "$id" "$FZF_SELECT_COUNT"' \
      --bind='enter:transform:if [ "$FZF_SELECT_COUNT" -gt 0 ]; then echo "print(delete)+accept"; else echo abort; fi') || picker_status=$?
  (( picker_status == 130 )) && exit 0
  (( picker_status == 0 || picker_status == 1 )) || fail "fzf failed with status $picker_status."
  fields=("${(@0)output}")
  (( ${#fields} >= 2 )) || exit 0
  query=${fields[1]}
  picker_action=${fields[2]}
  if [[ $picker_action == clear ]]; then
    selected_ids=()
    for (( id=1; id<=${#rows}; id++ )); do rows[$id]=$(jq -c '.force=false' <<<"${rows[$id]}"); done
    continue
  elif [[ $picker_action == all ]]; then
    selected_ids=()
    for (( id=0; id<${#rows}; id++ )); do selected_ids+=("$id"); done
    query=''
    continue
  fi
  selected_ids=()
  for item in "${fields[@]:2}"; do
    [[ -n $item ]] || continue
    id=${item%%$'\t'*}
    [[ $id == <-> ]] && (( id<${#rows} )) || fail 'fzf returned an invalid row.'
    selected_ids+=("$id")
  done
  [[ $picker_action != delete ]] || break
  action_fields=("${(@s/:/)picker_action}")
  (( ${#action_fields} == 3 )) || fail 'fzf returned an invalid action.'
  action_name=${action_fields[1]}
  [[ ${action_fields[3]} != 0 ]] || selected_ids=()
  if [[ -n ${action_fields[2]} ]]; then
    focus=${action_fields[2]}
    [[ $focus == <-> ]] && (( focus<${#rows} )) || fail 'fzf returned an invalid focus.'
  fi
  if [[ $action_name == force ]]; then
    required_ids=()
    force_required=false
    for (( id=0; id<${#rows}; id++ )); do
      row=${rows[$((id+1))]}
      [[ $(jq -r .reason <<<"$row") != '' ]] || continue
      required_ids+=("$id")
      if [[ $(jq -r .force <<<"$row") != true ]] || (( ${selected_ids[(Ie)$id]} == 0 )); then force_required=true; fi
    done
    for id in "${required_ids[@]}"; do
      rows[$((id+1))]=$(jq -c --argjson force "$force_required" '.force=$force' <<<"${rows[$((id+1))]}")
      if [[ $force_required == true ]]; then selected_ids+=("$id")
      else selected_ids=("${(@)selected_ids:#$id}"); fi
    done
    selected_ids=("${(@u)selected_ids}")
    continue
  fi
  id=$focus
  row=${rows[$((id+1))]}
  if (( ${selected_ids[(Ie)$id]} == 0 )); then mode=0
  elif [[ $(jq -r .force <<<"$row") == true ]]; then mode=2
  else mode=1
  fi
  case $action_name in next) step=1 ;; previous) step=2 ;; *) fail 'fzf returned an unknown action.' ;; esac
  mode=$(( (mode+step)%3 ))
  force=false
  (( mode!=2 )) || force=true
  rows[$((id+1))]=$(jq -c --argjson force "$force" '.force=$force' <<<"$row")
  selected_ids=("${(@)selected_ids:#$id}")
  (( mode==0 )) || selected_ids+=("$id")
done
(( ${#selected_ids} > 0 )) || exit 0
print '\nDelete these branches and worktrees:'
for id in "${selected_ids[@]}"; do print -r -- "  ${labels[$((id+1))]#*$'\t'}"; done
for id in "${selected_ids[@]}"; do
  if [[ $(jq -r .force <<<"${rows[$((id+1))]}") == true ]]; then
    print 'FORCE entries discard uncommitted changes, unmerged commits, locks and private submodule history.'
    break
  fi
done
if ! read -r 'answer?Delete selected entries? [Y/n] '; then print 'Cancelled.'; exit 0; fi
[[ -z $answer || $answer == y || $answer == Y ]] || { print 'Cancelled.'; exit 0; }

integer deleted=0 skipped=0 failed=0
for id in "${selected_ids[@]}"; do
  row=${rows[$((id+1))]}
  branch=$(jq -r .branch <<<"$row")
  head=$(jq -r .head <<<"$row")
  worktree_path=$(jq -jr '.path + "\u0000"' <<<"$row")
  worktree_path=${worktree_path%$'\0'}
  reason=$(jq -r .reason <<<"$row")
  force=$(jq -r .force <<<"$row")
  if [[ $force != true && -n $reason ]]; then
    print -u2 -r -- "Skipped $branch: $reason Use Tab to select FORCE, or Ctrl-F to force all blocked entries."
    (( skipped+=1 ))
    continue
  fi
  if [[ $force != true && -n $branch && $(git rev-parse --verify "refs/heads/$branch" 2>/dev/null || true) != $head ]]; then
    print -u2 -- "Skipped changed branch: $branch"
    (( skipped+=1 ))
    continue
  fi
  if [[ -n $worktree_path ]]; then
    removal_flags=()
    if [[ $force == true ]]; then removal_flags=(--force --force)
    else
      current_head=$(git -C "$worktree_path" rev-parse --verify HEAD 2>/dev/null || true)
      tree_branch=$(git -C "$worktree_path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
      if [[ $current_head != $head || $tree_branch != $branch ]]; then
        print -u2 -- "Skipped changed worktree: $(jq -Rn --arg path "$worktree_path" '$path')"
        (( skipped+=1 ))
        continue
      fi
      if ! removal_result=$(removal_options "$worktree_path" 2>&1); then
        print -u2 -r -- "Skipped $(jq -Rn --arg path "$worktree_path" '$path'): $removal_result"
        (( skipped+=1 ))
        continue
      fi
      [[ -z $removal_result ]] || removal_flags=(--force)
    fi
    if ! git worktree remove "${removal_flags[@]}" -- "$worktree_path"; then (( failed+=1 )); continue; fi
    print -- "Removed worktree: $(jq -Rn --arg path "$worktree_path" '$path')"
  fi
  if [[ -n $branch ]]; then
    if [[ $force != true && $(git rev-parse --verify "refs/heads/$branch" 2>/dev/null || true) != $head ]]; then
      print -u2 -- "Skipped changed branch: $branch"
      (( skipped+=1 ))
      continue
    fi
    git branch -D -- "$branch" || { (( failed+=1 )); continue; }
  fi
  (( deleted+=1 ))
done
print -- "Deleted $deleted; skipped $skipped; failed $failed."
(( skipped==0 && failed==0 ))
