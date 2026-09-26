# Keep Git's arguments separate from picker labels and paths.
def --wrapped nav-git [directory: string, ...args: string] {
  let result = (^git -C $directory ...$args | complete)
  if $result.exit_code != 0 {
    error make {msg: ($result.stderr | str trim)}
  }
  $result.stdout
}

def nav-worktrees [directory: string] {
  let trees = (
    nav-git $directory worktree list --porcelain -z
    | split row "\u{0}\u{0}"
    | where {|entry| $entry != "" }
    | each {|entry|
      let fields = ($entry | split row "\u{0}")
      {
        path: ($fields | first | str substring 9.. | path expand)
        branch: ($fields | where {|field| $field starts-with "branch refs/heads/" } | str join | str replace "branch refs/heads/" "")
        head: ($fields | where {|field| $field starts-with "HEAD " } | str join | str replace "HEAD " "")
      }
    }
  )
  # Submodules keep their main working directory in core.worktree; Git's
  # worktree list reports the internal Git directory instead.
  let common = (nav-git $directory rev-parse --path-format=absolute --git-common-dir | str trim --right --char "\n")
  let configured = (^git --git-dir $common config --get core.worktree | complete)
  if $configured.exit_code == 0 {
    $trees | update 0.path ($common | path join ($configured.stdout | str trim --right --char "\n") | path expand)
  } else {
    $trees
  }
}

# Navigate branches, worktrees, and submodules in this shell or a new window.
export def --env "git nav" [
  --new-window (-w) # Open the destination in a new Ghostty window.
] {
  let root = (nav-git $env.PWD rev-parse --show-toplevel | str trim --right --char "\n" | path expand)
  let worktrees = (nav-worktrees $root)
  let main = $worktrees.0.path
  let current = ($worktrees | where path == $root | first)
  let head = if $current.branch != "" { $current.branch } else { $current.head | str substring 0..7 }

  let branches = (
    nav-git $root for-each-ref '--format=%(refname:strip=2)' refs/heads/
    | lines
    | each {|branch|
      let checked_out = ($worktrees | where branch == $branch)
      {
        kind: (if ($checked_out | is-empty) { "branch" } else { "worktree" })
        name: $branch
        path: (if ($checked_out | is-empty) { $main } else { $checked_out.0.path })
      }
    }
  )
  let detached = ($worktrees | where branch == "" | each {|tree|
    {
      kind: "detached"
      name: $"($tree.path | path basename) @ ($tree.head | str substring 0..7)"
      path: $tree.path
    }
  })
  let submodules = (
    nav-git $root ls-files --stage -z
    | split row "\u{0}"
    | parse --regex '(?s)^160000 [^\t]+\t(?<path>.*)$'
    | get path
    | uniq
    | each {|path| {kind: "submodule", name: $path, path: ($root | path join $path)} }
  )
  let containing = (nav-git $root rev-parse --show-superproject-working-tree | str trim --right --char "\n")
  let parent = if $containing != "" { $containing } else {
    nav-git $main rev-parse --show-superproject-working-tree | str trim --right --char "\n"
  }
  let parents = if $parent == "" { [] } else { [{kind: "parent", name: ($parent | path basename), path: $parent}] }
  let destinations = (
    [{kind: "create", name: "+ Create branch…", path: $main}]
    | append $branches
    | append $detached
    | append $submodules
    | append $parents
  )
  let name_width = (($destinations | get name | str length | math max) + 2)
  let rows = ($destinations | enumerate | each {|row|
    let mark = if $row.item.path == $root and $row.item.kind in [worktree detached] { "●" } else { " " }
    # JSON escaping keeps tabs/newlines in paths out of the display columns.
    let location = if $row.item.path == $root { "." } else {
      try { $row.item.path | path relative-to $root } catch { $row.item.path }
    }
    let path = ($location | to json --raw)
    let name = ($row.item.name | fill --alignment left --width $name_width)
    let kind = ($row.item.kind | fill --alignment left --width 11)
    $"($row.index)\t($mark) ($name)\t($kind)\t($path)"
  } | str join "\u{0}")
  let selection = (
    $rows | ^fzf --read0 --print0 --delimiter "\t" --with-nth 2.. --nth 1,2
      --layout reverse --wrap --tiebreak begin,index --no-multi --no-select-1 --no-exit-0
      --expect ctrl-n,ctrl-o --prompt "Repository > "
      --header $"($root | path basename) · ($head)\nEnter: (if $new_window { 'new window' } else { 'go' })   Ctrl+O: new window   Ctrl+N: create branch   Esc: cancel"
    | complete
  )
  if $selection.exit_code == 130 { return }
  if $selection.exit_code not-in [0 1] {
    error make {msg: ($selection.stderr | str trim)}
  }
  let selected = ($selection.stdout | split row "\u{0}")
  # fzf returns 1 for Ctrl+N when the current query has no matching rows.
  if $selection.exit_code == 1 and $selected.0 != "ctrl-n" { return }
  let destination = if $selected.0 == "ctrl-n" {
    $destinations.0
  } else {
    let index = ($selected.1 | split row "\t" | first | into int)
    $destinations | get $index
  }

  let target = if $destination.kind == "create" {
    let starting_commit = $current.head
    if $starting_commit =~ '^0+$' {
      error make {msg: "Commit before creating another branch with git nav."}
    }
    print $"New branch in ($main)"
    let name = (try { input "Branch name (empty cancels): " | str trim } catch { null })
    if $name == null or $name == "" { return }
    let checked_name = (nav-git $root check-ref-format --branch $name | str trim)
    if $checked_name != $name {
      error make {msg: "Enter a literal branch name."}
    }
    let start = (try { input $"Starting point [($starting_commit | str substring 0..7)]: " | str trim } catch { null })
    if $start == null { return }
    let commit = if $start == "" {
      $starting_commit
    } else {
      nav-git $root rev-parse --verify --end-of-options $"($start)^{commit}" | str trim
    }
    nav-git $main switch -c $name $commit | ignore
    $main
  } else if $destination.kind in [branch worktree] {
    # Refresh ownership: another terminal may have checked out this branch.
    let owners = (nav-worktrees $root | where branch == $destination.name)
    if ($owners | is-empty) {
      nav-git $main switch --no-guess $destination.name | ignore
      $main
    } else {
      $owners.0.path
    }
  } else {
    # An uninitialized submodule directory still belongs to the parent repo.
    let target = (nav-git $destination.path rev-parse --show-toplevel | str trim --right --char "\n" | path expand)
    if $target != ($destination.path | path expand) {
      error make {msg: $"($destination.name) is not an initialized checkout. Initialize the submodule before navigating to it."}
    }
    $target
  }

  if $new_window or $selected.0 == "ctrl-o" {
    let launched = if $nu.os-info.name == "macos" {
      ^/usr/bin/open -na Ghostty --args $"--working-directory=($target)" --window-save-state=never | complete
    } else {
      ^ghostty +new-window $"--working-directory=($target)" | complete
    }
    if $launched.exit_code != 0 {
      error make {msg: ($launched.stderr | str trim)}
    }
  } else {
    cd $target
  }
}
