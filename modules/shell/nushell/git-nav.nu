use ../scripts/git.nu [git-output worktrees]

# Navigate branches, worktrees, and submodules in this shell or a new window.
export def --env "git nav" [
  --new-window (-w) # Open the destination in a new Ghostty window.
] {
    let root = (
        git-output $env.PWD rev-parse --show-toplevel
        | str trim --right --char "\n"
        | path expand
    )
    let worktrees = (worktrees $root)
    let main = $worktrees.0.path
    let current = $worktrees | where path == $root | first
    let head = if $current.branch != "" { $current.branch } else {
        $current.head | str substring 0..7
    }

    let branches = (
    git-output $root for-each-ref '--format=%(refname:strip=2)' refs/heads/
    | lines
    | each {|branch|
      let checked_out = $worktrees | where branch == $branch
      {
        kind: (if ($checked_out | is-empty) { "branch" } else { "worktree" })
        name: $branch
        path: (if ($checked_out | is-empty) { $main } else { $checked_out.0.path })
      }
    }
  )
    let detached = ($worktrees | where branch == "" | each {|tree|
    {
      kind: "detached", 
      name: $"($tree.path | path basename) @ ($tree.head | str substring 0..7)"
      path: $tree.path
    }
  })
    let submodules = (
    git-output $root ls-files --stage -z
    | split row "\u{0}"
    | parse --regex '(?s)^160000 [^\t]+\t(?<path>.*)$'
    | get path
    | uniq
    | each {|path| {kind: "submodule", name: $path, path: ($root | path join $path)} }
  )
    let containing = (
        git-output $root rev-parse --show-superproject-working-tree
        | str trim --right --char "\n"
    )
    let parent = if $containing != "" { $containing } else {
        git-output $main rev-parse --show-superproject-working-tree | str trim --right --char "\n"
    }
    let parents = if $parent == "" { [] } else { [
        {
            kind: "parent"
            name: ($parent | path basename)
            path: $parent
        }
    ] }
    let destinations = (
    [{kind: "create", name: "+ Create branch…", path: $main}]
    | append $branches
    | append $detached
    | append $submodules
    | append $parents
  )
    let name_width = ((
        $destinations
        | get name
        | str length
        | math max
    ) + 2)
    let rows = ($destinations | enumerate | each {|row|
    let mark = if $row.item.path == $root and $row.item.kind in [worktree detached] { "●" } else { " " }
    # JSON escaping keeps tabs/newlines in paths out of the display columns.
    let location = if $row.item.path == $root { "." } else {
      try { $row.item.path | path relative-to $root } catch { $row.item.path }
    }
    let path = $location | to json --raw
    let name = $row.item.name | fill --alignment left --width $name_width
    let label = if $row.item.path == $main and $row.item.kind in [worktree detached] { "main" } else { $row.item.kind }
    let kind = $label | fill --alignment left --width 11
    $"($row.index)\t($mark) ($name)\t($kind)\t($path)"
  } | str join "\u{0}")
    let selection = (
    $rows | ^fzf --read0 --print0 --delimiter "\t" --with-nth 2.. --nth 1,2
      --layout reverse --wrap --tiebreak begin,index --no-multi --no-select-1 --no-exit-0
      --expect ctrl-n,ctrl-t --prompt "Repository > "
      --header $"($root | path basename) · ($head)\nEnter: (if $new_window { 'new window' } else { 'go' })   Ctrl+T: new window   Ctrl+N: create branch   Esc: cancel"
    | complete
  )
    if $selection.exit_code == 130 { return }
    if $selection.exit_code not-in [0 1] {
        error make {
            msg: ($selection.stderr | str trim)
        }
    }
    let selected = $selection.stdout | split row "\u{0}"
    # fzf returns 1 for Ctrl+N when the current query has no matching rows.
    if $selection.exit_code == 1 and $selected.0 != "ctrl-n" { return }
    let destination = if $selected.0 == "ctrl-n" {
        $destinations.0
    } else {
        let index = (
            $selected.1
            | split row "\t"
            | first
            | into int
        )
        $destinations | get $index
    }

    let target = if $destination.kind == "create" {
        let starting_commit = $current.head
        if $starting_commit =~ '^0+$' {
            error make {msg: "Commit before creating another branch with git nav."}
        }
        print $"New branch in ($main)"
        let name = (
            try {
                input "Branch name (empty cancels): " | str trim
            } catch { null }
        )
        if $name == null or $name == "" { return }
        let checked_name = git-output $root check-ref-format --branch $name | str trim
        if $checked_name != $name {
            error make {msg: "Enter a literal branch name."}
        }
        git-output $main switch -c $name $starting_commit | ignore
        $main
    } else if $destination.kind in [branch worktree] {
        # Refresh ownership: another terminal may have checked out this branch.
        let owners = worktrees $root | where branch == $destination.name
        if ($owners | is-empty) {
            git-output $main switch --no-guess $destination.name | ignore
            $main
        } else {
            $owners.0.path
        }
    } else {
        # An uninitialized submodule directory still belongs to the parent repo.
        let target = (
            git-output $destination.path rev-parse --show-toplevel
            | str trim --right --char "\n"
            | path expand
        )
        if $target != ($destination.path | path expand) {
            error make {msg: $"($destination.name) is not an initialized checkout. Initialize the submodule before navigating to it."}
        }
        $target
    }

    if $new_window or $selected.0 == "ctrl-t" {
        let launched = if $nu.os-info.name == "macos" {
            ^/usr/bin/open -na Ghostty --args $"--working-directory=($target)" --window-save-state=never | complete
        } else {
            ^ghostty +new-window $"--working-directory=($target)" | complete
        }
        if $launched.exit_code != 0 {
            error make {
                msg: ($launched.stderr | str trim)
            }
        }
    } else {
        cd $target
    }
}
