# Find manifests from the current directory to the checkout boundary.
def package-directories [] {
    let git = (^git rev-parse --show-toplevel | complete)
    let boundary = if $git.exit_code == 0 {
        $git.stdout | str trim --right --char "\n" | path expand
    } else {
        $env.PWD | path expand
    }
    mut directory = $env.PWD | path expand
    mut directories = []
    loop {
        $directories = ($directories | append $directory)
        if $directory == $boundary { break }
        let parent = $directory | path dirname
        if $parent == $directory { break }
        $directory = $parent
    }
    $directories
}

def read-package [directory: path] {
    let manifest = $directory | path join package.json
    if not ($manifest | path exists) { return {} }
    try {
        let package = open --raw $manifest | from json
        if ($package | describe --detailed | get type) != record {
            error make {msg: "Expected a JSON object."}
        }
        $package
    } catch {|error| error make {msg: $"Cannot read ($manifest): ($error.msg)"} }
}

# Workspace packages often inherit their manager from an ancestor manifest.
def package-manager [packages: list<any>] {
    for package in $packages {
        let declared = $package.manifest.packageManager? | default ""
        if $declared != "" {
            let manager = $declared | split row "@" | first
            if $manager not-in [npm pnpm yarn bun] {
                error make {msg: $"Unsupported package manager in ($package.directory)/package.json: ($declared)"}
            }
            return $manager
        }
        for lock in [
            {file: pnpm-lock.yaml, manager: pnpm}
            {file: yarn.lock, manager: yarn}
            {file: bun.lock, manager: bun}
            {file: bun.lockb, manager: bun}
            {file: package-lock.json, manager: npm}
            {file: npm-shrinkwrap.json, manager: npm}
        ] {
            if ($package.directory | path join $lock.file | path exists) {
                return $lock.manager
            }
        }
    }
    "npm"
}

# Keep terminal control characters and column separators out of picker labels.
def label [value: string] {
    $value | str replace -ar '[\x00-\x1f\x7f]' ' '
}

# Fuzzy-search package.json scripts and run the selection in its package folder.
def main [] {
    let packages = (package-directories | each {|directory|
    {directory: $directory, manifest: (read-package $directory)}
  })
    let root = $packages.directory | last
    let scripts = ($packages | enumerate | each {|package|
    let scripts = $package.item.manifest.scripts? | default {}
    if ($scripts | describe --detailed | get type) != record {
      error make {msg: $"Expected a scripts object in ($package.item.directory)/package.json."}
    }
    $scripts | transpose name command | sort-by name | each {|script|
      if ($script.command | describe) != string {
        error make {msg: $"Script ($script.name) in ($package.item.directory)/package.json must be a string."}
      }
      {
        name: $script.name
        command: $script.command
        directory: $package.item.directory
        package_index: $package.index
      }
    }
  } | flatten)
    if ($scripts | is-empty) {
        error make {msg: "No package.json scripts found in this directory or its repository ancestors."}
    }
    let rows = ($scripts | enumerate | each {|row|
    let script = $row.item
    let location = $script.directory | path relative-to $root
    let location = if $location == "" { "." } else { $location }
    $"($row.index)\t(label $script.name)\t(label $location)\t(label $script.command)"
  } | str join "\u{0}")
    let selection = (
    $rows | ^fzf --read0 --print0 --delimiter "\t" --with-nth 2..
      --layout reverse --wrap --no-multi --no-select-1 --no-exit-0
      --prompt "Run > " --header "Script · package · command | Enter: run · Esc: cancel"
    | complete
  )
    if $selection.exit_code in [1 130] { return }
    if $selection.exit_code != 0 {
        error make {
            msg: ($selection.stderr | str trim)
        }
    }
    let index = (
        $selection.stdout
        | split row "\t"
        | first
        | into int
    )
    let script = $scripts | get $index
    let manager = package-manager ($packages | skip $script.package_index)
    if (which $manager | is-empty) {
        error make {msg: $"($manager) is not on PATH. Enter this project's development environment first."}
    }
    print $"(label $script.directory)> ($manager) run ($script.name | to json --raw)"
    cd $script.directory
    # Replace only this helper, preserving interactive stdin, signals and exit status.
    exec $manager run $script.name
}
