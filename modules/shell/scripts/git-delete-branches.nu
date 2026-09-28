use git.nu [git-output worktrees]

def is-merged [head: string, base: string] {
    if (^git merge-base --is-ancestor $head $base | complete).exit_code == 0 { return true }
    let fork = (^git merge-base $base $head | complete)
    if $fork.exit_code != 0 { return false }
    let fork = $fork.stdout | str trim
    # Rebase/cherry-pick changes commit IDs. Do not ignore merge-only changes.
    if (git-output $env.PWD rev-list --merges $"($base)..($head)" | str trim) == "" {
        let cherry = (^git cherry $base $head | complete)
        if $cherry.exit_code == 0 and not ($cherry.stdout | str contains '+') { return true }
    }
    # A squash represents the branch's combined diff as one upstream patch.
    let patch = (
        git-output $env.PWD diff --no-ext-diff --no-textconv --binary $fork $head
        | ^git patch-id --stable
        | complete
    )
    if $patch.exit_code != 0 { return false }
    let patch = $patch.stdout | split row ' ' | first
    if $patch == "" { return true }
    let merged = (
        git-output $env.PWD log --no-ext-diff --no-textconv --no-merges '--pretty=format:%H' -p --binary $"($fork)..($base)"
        | ^git patch-id --stable
        | complete
    )
    $merged.exit_code == 0 and ($merged.stdout | str contains $"($patch) ")
}

def candidate [row: record, base: string, devenv: string] {
    if $row.path != "" and ($devenv == $row.path or ($devenv | str starts-with $"($row.path)/")) {
        print --stderr $"Keeping active devenv worktree: ($row.path | to json --raw) \(exit devenv before deleting it\)."
        return null
    }
    let reason = if $row.locked { "Worktree is locked." } else if $row.path == "" { "" } else {
        try {
            removal-options $row.path | ignore
            ""
        } catch {|error| $error.msg }
    }
    let status = if $row.locked { "LOCKED" } else if $reason != "" {
        if ($reason | str starts-with "Uncommitted changes") { "DIRTY" } else { "BLOCKED" }
    } else if (is-merged $row.head $base) { "merged" } else { "UNMERGED" }
    let reason = if $status == "UNMERGED" { "Commits are not merged into the default reference." } else { $reason }
    let name = if $row.branch == "" { $"\(detached ($row.head | str substring 0..7)\)" } else { $row.branch }
    let location = if $row.path == "" { "" } else { $"  worktree: ($row.path | to json --raw)" }
    $row | merge {label: $"($name) [($status)]($location)", reason: $reason, force: false}
}

def require-clean [directory: string] {
    let changes = (
        git-output $directory status --porcelain --untracked-files=all --ignore-submodules=none
    )
    if $changes != "" {
        error make {msg: $"Uncommitted changes in ($directory | to json --raw); commit or save them first."}
    }
}

# --force also bypasses Git's dirty check, so inspect everything it would delete.
def removal-options [directory: string] {
    require-clean $directory
    let modules = (
        git-output $directory submodule foreach --quiet --recursive 'printf "%s\0" "$toplevel/$sm_path"'
        | split row (char nul) | where {|path| $path != "" }
    )
    mut repositories = []
    for module in $modules {
        require-clean $module
        $repositories = ($repositories | append (
            git-output $module rev-parse --absolute-git-dir | str trim --right --char "\n"
        ))
    }
    let private_modules = (
        git-output $directory rev-parse --absolute-git-dir
        | str trim --right --char "\n" | path join modules
    )
    # Deinitialized or removed submodules can still have private branches/stashes.
    let has_private_modules = $private_modules | path exists
    if $has_private_modules {
        let archived = (do {
            cd $private_modules
            glob **/config | each {|file| $file | path dirname }
        })
        $repositories = ($repositories | append $archived)
    }
    for repository in ($repositories | uniq) {
        let stash = (
            git-output $directory --git-dir $repository for-each-ref '--format=%(refname)' refs/stash
        )
        if $stash != "" {
            error make {msg: $"Submodule repository ($repository | to json --raw) has a stash; preserve it before deleting."}
        }
        # HEAD covers detached commits; reflogs cover commits on deleted branches.
        let local = (
            git-output $directory --git-dir $repository rev-list --max-count=1 HEAD --all --reflog --not --remotes
        )
        if $local != "" {
            error make {msg: $"Submodule repository ($repository | to json --raw) has history outside recorded remote branches \(($local | str trim)\); preserve it or fetch its remote before retrying."}
        }
    }
    if ($modules | is-not-empty) or $has_private_modules { [--force] } else { [] }
}

# Restart after selection changes, preserving the focused row and hidden selections.
# Only numeric row IDs enter fzf actions; labels and queries remain data.
def pick-entries [entries: list<any>, base: string] {
    mut rows = $entries
    mut selected = $rows | enumerate | where item.reason == "" | get index
    mut query = ""
    mut focus = 0
    loop {
        let labels = ($rows | enumerate | each {|row|
            let mode = if $row.item.force { "[FORCE] " } else { "" }
            let reason = if $row.item.reason == "" { "" } else { $"  ($row.item.reason)" }
            $"($row.index)\t($mode)($row.item.label)($reason)"
        } | str join (char nul))
        let restore = (
            $selected
            | each {|id| $"pos\(($id + 1)\)+select" }
            | append $"pos\(($focus + 1)\)"
            | str join '+'
        )
        let result = (with-env {FZF_DEFAULT_OPTS: '', FZF_DEFAULT_OPTS_FILE: '', GIT_DB_QUERY: $query} {
            ($labels | ^fzf --multi --sync --read0 --print0 --print-query --layout=reverse --track
                --delimiter "\t" --with-nth 2.. --with-shell 'bash -c' --prompt 'Delete> '
                --header $"Tab cycle state | Shift-Tab reverse | Ctrl-F force required | Ctrl-A all | Ctrl-D clear | Enter review | Esc cancel\nStates: unselected > selected > FORCE. Arrows move. Search keeps hidden selections.\nFORCE discards changes, locks and submodule history. UNMERGED compares with ($base)."
                --bind $"load:clear-selection+($restore)+transform-query\(printf '%s' \"$GIT_DB_QUERY\"\)+end-of-line"
                --bind 'tab:transform:id={1}; if [ -n "$id" ]; then printf "print(next:%s:%s)+accept" "$id" "$FZF_SELECT_COUNT"; fi'
                --bind 'btab:transform:id={1}; if [ -n "$id" ]; then printf "print(previous:%s:%s)+accept" "$id" "$FZF_SELECT_COUNT"; fi'
                --bind 'ctrl-d:print(clear)+accept,esc:abort'
                --bind 'ctrl-a:print(all)+accept'
                --bind 'ctrl-f:transform:id={1}; printf "print(force:%s:%s)+accept" "$id" "$FZF_SELECT_COUNT"'
                --bind 'enter:transform:if [ "$FZF_SELECT_COUNT" -gt 0 ]; then echo "print(delete)+accept"; else echo abort; fi'
                | complete)
        })
        if $result.exit_code == 130 { return [] }
        if $result.exit_code not-in [0 1] { error make {msg: $result.stderr} }
        let output = $result.stdout | split row (char nul)
        if ($output | length) < 2 { return [] }
        $query = $output.0
        if $output.1 == "clear" {
            $selected = []
            $rows = ($rows | update force false)
            continue
        }
        if $output.1 == "all" {
            $selected = $rows | enumerate | get index
            $query = ""
            continue
        }
        let action = $output.1 | split row ':'
        $selected = ($output | skip 2 | where {|line| $line != "" } | each {|line|
            $line | split row "\t" | first | into int
        })
        if $action.0 == "delete" {
            let entries = $rows
            return ($selected | each {|id| $entries | get $id })
        }
        # With zero selections, fzf accepts the focused row as a fallback.
        if ($action.2 | into int) == 0 { $selected = [] }
        if $action.1 != "" { $focus = $action.1 | into int }
        if $action.0 == "force" {
            let required = $rows | enumerate | where item.reason != ""
            let selection = $selected
            let force = not (
                $required
                | all {|row| $row.item.force and $row.index in $selection }
            )
            let ids = $required | get index
            $rows = ($rows | each {|row|
                if $row.reason != "" { $row | update force $force } else { $row }
            })
            $selected = if $force {
                $selected | append $ids | uniq
            } else {
                $selected | where {|id| $id not-in $ids }
            }
            continue
        }
        let id = $focus
        let row = $rows | get $id
        let state = if $id not-in $selected { 0 } else if $row.force { 2 } else { 1 }
        let step = if $action.0 == "next" { 1 } else { 2 }
        let state = ($state + $step) mod 3
        $rows = ($rows | update $id ($row | update force ($state == 2)))
        $selected = ($selected | where {|selected| $selected != $id })
        if $state != 0 { $selected = ($selected | append $id) }
    }
}

# Worktree directories are independent; branch deletion later stays serial because
# Git also updates the shared repository config when deleting a branch.
def remove-worktree [row: record] {
    if not $row.force {
        if $row.reason != "" {
            print --stderr $"Skipped ($row.label): ($row.reason) Use Tab to select FORCE, or Ctrl-F to force all blocked entries."
            return "skipped"
        }
        if $row.branch != "" and ((^git rev-parse --verify $"refs/heads/($row.branch)" | complete).stdout | str trim) != $row.head {
            print --stderr $"Skipped changed branch: ($row.branch)"
            return "skipped"
        }
    }
    if $row.path == "" { return "ready" }
    let options = if $row.force { [--force --force] } else {
        let head = (^git -C $row.path rev-parse --verify HEAD | complete).stdout | str trim
        let branch = (
            (^git -C $row.path symbolic-ref --quiet --short HEAD | complete).stdout
            | str trim
        )
        if $head != $row.head or $branch != $row.branch {
            print --stderr $"Skipped changed worktree: ($row.path | to json --raw)"
            return "skipped"
        }
        let options = (try { removal-options $row.path } catch {|error|
            print --stderr $"Skipped ($row.path | to json --raw): ($error.msg)"
            null
        })
        if $options == null { return "skipped" }
        $options
    }
    let removed = (^git worktree remove ...$options -- $row.path | complete)
    if $removed.exit_code != 0 {
        print --stderr $"Failed removing ($row.path | to json --raw): ($removed.stderr | str trim)"
        return "failed"
    }
    print $"Removed worktree: ($row.path | to json --raw)"
    "ready"
}

def main [] {
    let inside = (^git rev-parse --is-inside-work-tree | complete)
    if $inside.exit_code != 0 or ($inside.stdout | str trim) != "true" {
        print --stderr "Not in a git repo!"
        exit 1
    }
    let root = (
        git-output $env.PWD rev-parse --show-toplevel
        | str trim --right --char "\n"
        | path expand
    )
    let trees = (worktrees $root)
    let main = $trees.0
    let current = (^git symbolic-ref --quiet --short HEAD | complete).stdout | str trim
    # The shell can cd elsewhere while devenv still watches its original worktree.
    let devenv = $env.DEVENV_ROOT? | default ""
    let devenv = if $devenv == "" { "" } else {
        $devenv | path expand
    }
    mut base = (
        (^git symbolic-ref --quiet refs/remotes/origin/HEAD | complete).stdout
        | str trim
    )
    mut default_branch = $base | str replace 'refs/remotes/origin/' ''
    if $default_branch == "" {
        for branch in [main master $main.branch] {
            if $branch != "" and (^git show-ref --verify --quiet $"refs/heads/($branch)" | complete).exit_code == 0 {
                $default_branch = $branch
                $base = $"refs/heads/($branch)"
                break
            }
        }
    }
    if $base == "" { $base = "HEAD" }
    let base = $base
    let default_branch = $default_branch
    if (^git rev-parse --verify $"($base)^{commit}" | complete).exit_code != 0 {
        print --stderr $"Cannot resolve ($base) to compare branches."
        exit 1
    }
    let branches = (
    git-output $root for-each-ref '--format=%(refname:strip=2)%09%(objectname)' refs/heads/
    | lines | split column "\t" branch head
    | where {|row| $row.branch not-in [$current $default_branch $main.branch] }
    | each {|row|
      let tree = $trees | where branch == $row.branch | get -o 0
      $row | merge {path: ($tree.path? | default ""), locked: ($tree.locked? | default false)}
    }
  )
    let rows = (
    $branches | append ($trees | where branch == "")
    | where {|row| $row.path not-in [$root $main.path] }
    | par-each --threads 8 --keep-order {|row| candidate $row $base $devenv }
  )
    if ($rows | is-empty) {
        print "No branches or worktrees to delete."
        return
    }
    let selected = pick-entries $rows $base
    if ($selected | is-empty) { return }
    print "\nDelete these branches and worktrees:"
    for row in $selected {
        let mode = if $row.force { "[FORCE] " } else { "" }
        print $"  ($mode)($row.label)"
    }
    if ($selected | any {|row| $row.force }) {
        print "FORCE entries discard uncommitted changes, unmerged commits and private submodule history, including locked worktrees."
    }
    let answer = (
        try { input $"\nDelete ($selected | length) selected entries? [Y/n] " } catch { null }
    )
    if $answer not-in ["" y Y] {
        print "Cancelled."
        return
    }
    print $"Removing ($selected | length) entries, up to 8 worktrees at a time..."
    let results = ($selected | par-each --threads 8 --keep-order {|row|
        $row | insert result (remove-worktree $row)
    })
    mut deleted_count = 0
    mut skipped_count = $results | where result == "skipped" | length
    mut failed_count = $results | where result == "failed" | length
    for row in ($results | where result == "ready") {
        if $row.branch != "" {
            if not $row.force and ((^git rev-parse --verify $"refs/heads/($row.branch)" | complete).stdout | str trim) != $row.head {
                print --stderr $"Skipped changed branch: ($row.branch)"
                $skipped_count += 1
                continue
            }
            # Patch-equivalent squash/rebase merges need -D even in normal mode.
            let deleted = (^git branch -D -- $row.branch | complete)
            print --no-newline $deleted.stdout
            if $deleted.exit_code != 0 {
                print --stderr $deleted.stderr
                $failed_count += 1
                continue
            }
        }
        $deleted_count += 1
    }
    print $"Deleted ($deleted_count); skipped ($skipped_count); failed ($failed_count)."
    if $skipped_count > 0 or $failed_count > 0 { exit 1 }
}
