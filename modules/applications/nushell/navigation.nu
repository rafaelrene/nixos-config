# Pick a local directory or SSH host without leaving the current terminal.
export def --env nav [] {
    let settings = open @nav-settings@
    let destinations = destinations $settings
    let rows = ($destinations | enumerate | each {|row|
        # Only the index is used for selection. Escape control characters in labels.
        let label = $"($row.item.name)  ·  ($row.item.kind)  ·  ($row.item.path)"
            | str replace -ar '[\x00-\x1f\x7f]' ' '
        $"($row.index)\t($label)"
    } | str join (char nul))
    let selection = (
        $rows | ^fzf --read0 --print0 --delimiter "\t" --with-nth 2.. --nth 1..
            --layout reverse --no-multi --no-select-1 --no-exit-0
            --prompt 'Destination > ' --header 'Enter: cd / ssh   Esc: cancel'
        | complete
    )
    if $selection.exit_code in [1 130] { return }
    if $selection.exit_code != 0 {
        error make {
            msg: ($selection.stderr | str trim)
        }
    }
    let index = $selection.stdout | split row "\t" | first | into int
    let destination = $destinations | get $index
    if $destination.kind == ssh {
        ^ssh $destination.path
    } else {
        cd $destination.path
    }
}

def directories [root: string] {
    try {
        ls -a $root | where {|entry| ($entry.name | path expand | path type) == dir } | get name | sort
    } catch { [] }
}

def repositories [root: string] {
    if ($root | path type) != dir { return [] }
    # Prune repository roots and caches; nested repositories belong to git nav.
    let excluded = [
        node_modules
        vendor
        target
        dist
        build
        .devenv
        .direnv
        .cache
        .opencode
    ]
    | each {|name| [--exclude $name] }
    | flatten
    let result = (
        ^fd --hidden --no-ignore --prune --type d --type f --glob .git --absolute-path --print0 ...$excluded $root
        | complete
    )
    if $result.exit_code != 0 {
        error make {
            msg: ($result.stderr | str trim)
        }
    }
    $result.stdout
    | split row (char nul)
    | where {|path| $path != "" }
    | each {|path| $path | path dirname | path expand }
    | uniq
    | sort
    | reduce --fold [] {|path, roots|
        if ($roots | any {|parent| $path | str starts-with $"($parent)/" }) {
            $roots
        } else { $roots | append $path }
    }
}

def local-destination [kind: string, name: string, directory: string] {
    {
        kind: $kind
        name: $name
        path: ($directory | path expand)
    }
}

def destinations [settings: record] {
    let config = $settings.home | path join .config
    let roots = [
        (local-destination home Home $settings.home)
        (local-destination code Code $settings.code)
        (local-destination config Config $config)
    ] | where {|row| ($row.path | path type) == dir }
    let projects = (repositories $settings.code | each {|path|
        local-destination project ($path | path relative-to ($settings.code | path expand)) $path
    })
    let apps = (directories $config | each {|path|
        local-destination config $"Config / ($path | path basename)" $path
    })
    let hosts = ($settings.sshHosts | each {|host|
        {kind: ssh, name: $host, path: $host}
    })
    $roots | append $projects | append $apps | append $hosts | uniq-by kind path
}
