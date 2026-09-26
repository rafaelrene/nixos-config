# Keep Git's arguments separate from picker labels and paths.
export def --wrapped git-output [directory: string, ...args: string] {
    let result = (^git -C $directory ...$args | complete)
    if $result.exit_code != 0 {
        error make {
            msg: ($result.stderr | str trim)
        }
    }
    $result.stdout
}

export def worktrees [directory: string] {
    let trees = (
    git-output $directory worktree list --porcelain -z
    | split row "\u{0}\u{0}"
    | where {|entry| $entry != "" }
    | each {|entry|
      let fields = $entry | split row "\u{0}"
      {
        path: ($fields | first | str substring 9.. | path expand)
        branch: ($fields | where {|field| $field starts-with "branch refs/heads/" } | str join | str replace "branch refs/heads/" "")
        head: ($fields | where {|field| $field starts-with "HEAD " } | str join | str replace "HEAD " "")
      }
    }
  )
    # Submodules keep their main working directory in core.worktree; Git's
    # worktree list reports the internal Git directory instead.
    let common = (
        git-output $directory rev-parse --path-format=absolute --git-common-dir
        | str trim --right --char "\n"
    )
    let configured = (^git --git-dir $common config --get core.worktree | complete)
    if $configured.exit_code == 0 {
        $trees | update 0.path (
            $common
            | path join ($configured.stdout | str trim --right --char "\n")
            | path expand
        )
    } else {
        $trees
    }
}
