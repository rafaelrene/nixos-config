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
    let status = if $row.path == "" { {exit_code: 0, stdout: ""} } else {
        ^git -C $row.path status --porcelain --untracked-files=normal --ignore-submodules=none | complete
    }
    let status = if $status.exit_code != 0 { "UNKNOWN" } else if $status.stdout != "" {
        "DIRTY"
    } else if (is-merged $row.head $base) { "merged" } else { "UNMERGED" }
    let name = if $row.branch == "" { $"\(detached ($row.head | str substring 0..7)\)" } else { $row.branch }
    let location = if $row.path == "" { "" } else { $"  worktree: ($row.path | to json --raw)" }
    $row | insert label $"($name) [($status)]($location)"
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
      $row | insert path ($trees | where branch == $row.branch | get -o 0.path | default "")
    }
  )
    let rows = (
    $branches | append ($trees | where branch == "")
    | where {|row| $row.path not-in [$root $main.path] }
    | each {|row| candidate $row $base $devenv }
  )
    if ($rows | is-empty) {
        print "No branches or worktrees to delete."
        return
    }
    let labels = (
        $rows
        | enumerate
        | each {|row| $"($row.index)\t($row.item.label)" }
        | str join (char nul)
    )
    # These two small fzf bindings use Bash regardless of the user's login shell.
    # Ignore defaults that could auto-accept or change the returned row format.
    let selection = (with-env {FZF_DEFAULT_OPTS: '', FZF_DEFAULT_OPTS_FILE: ''} {
    ($labels | ^fzf --multi --sync --read0 --print0 --layout=reverse
      --delimiter "\t" --with-nth 2.. --with-shell 'bash -c' --prompt 'Delete> '
      --header $"Tab/Shift-Tab toggle | Ctrl-A select all | Ctrl-D clear all | Enter review | Esc cancel\nSearch keeps hidden selections. Branch rows also remove their worktree.\nDIRTY = uncommitted changes. UNMERGED compares commits with ($base)."
      --bind 'start:select-all+unbind(result),result:select-all+unbind(result)'
      --bind 'tab:toggle+down,btab:toggle+up,ctrl-d:clear-selection,esc:abort'
      --bind 'ctrl-a:transform:if [ -n "$FZF_QUERY" ]; then echo "rebind(result)+clear-query"; else echo select-all; fi'
      --bind 'enter:transform:if [ "$FZF_SELECT_COUNT" -gt 0 ]; then echo accept; else echo abort; fi'
    | complete)
  })
    if $selection.exit_code in [1 130] { return }
    if $selection.exit_code != 0 {
        print --stderr $selection.stderr
        exit $selection.exit_code
    }
    let selected = ($selection.stdout | split row (char nul) | where {|row| $row != "" } | each {|row|
    $rows | get ($row | split row "\t" | first | into int)
  })
    if ($selected | is-empty) { return }
    print "\nDelete these branches and worktrees (including unmerged commits):"
    for row in $selected { print $"  ($row.label)" }
    let answer = (
        try { input $"\nDelete ($selected | length) selected entries? [Y/n] " } catch { null }
    )
    if $answer not-in ["" y Y] {
        print "Cancelled."
        return
    }
    mut status = 0
    mut deleted_count = 0
    mut skipped_count = 0
    mut failed_count = 0
    for row in $selected {
        # A checkout or commit may have changed while the picker was open.
        if $row.branch != "" and ((^git rev-parse --verify $"refs/heads/($row.branch)" | complete).stdout | str trim) != $row.head {
            print --stderr $"Skipped changed branch: ($row.branch)"
            $status = 1
            $skipped_count += 1
            continue
        }
        if $row.path != "" {
            let head = (
                (^git -C $row.path rev-parse --verify HEAD | complete).stdout
                | str trim
            )
            let branch = (
                (^git -C $row.path symbolic-ref --quiet --short HEAD | complete).stdout
                | str trim
            )
            if $head != $row.head or $branch != $row.branch {
                print --stderr $"Skipped changed worktree: ($row.path | to json --raw)"
                $status = 1
                $skipped_count += 1
                continue
            }
            let options = (try { removal-options $row.path } catch {|error|
                print --stderr $"Skipped ($row.path | to json --raw): ($error.msg)"
                null
            })
            if $options == null {
                $status = 1
                $skipped_count += 1
                continue
            }
            # One --force permits submodules; Git still refuses locked/main trees.
            let removed = (^git worktree remove ...$options -- $row.path | complete)
            if $removed.exit_code != 0 {
                print --stderr $"Failed removing ($row.path | to json --raw): ($removed.stderr | str trim)"
                $status = 1
                $failed_count += 1
                continue
            }
        }
        if $row.branch != "" {
            let deleted = (^git branch -D -- $row.branch | complete)
            print --no-newline $deleted.stdout
            if $deleted.exit_code != 0 {
                print --stderr $deleted.stderr
                $status = 1
                $failed_count += 1
                continue
            }
        }
        $deleted_count += 1
    }
    print $"Deleted ($deleted_count); skipped ($skipped_count); failed ($failed_count)."
    exit $status
}
