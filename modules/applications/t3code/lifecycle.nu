def generation [profile: path] {
    if ($profile | path exists) {
        ^readlink -f $profile | str trim
    } else { null }
}

def active [settings: record] {
    generation $settings.profile | default $settings.initial
}

def desktops [] {
    let uid = ^id -u | str trim | into int
    let candidates = ps --long | where {|p|
        ($p.user_id == $uid
        and ($p.name =~ '^T3 Code \(' or $p.name in [t3code t3code-desktop])
        and ($p.command =~ '/nix/store/.*t3code-desktop' or $p.command =~ '/nix/profiles/t3code/')
        and $p.command !~ ' --type=')
    }
    # Electron workers can use the main executable too. Only manage their parent.
    $candidates | where {|p| $p.ppid not-in $candidates.pid }
}

def desktop-current [client: record, target: string] {
    let version = open ($target | path join share t3code release.json) | get version
    # A process launched through a mutable profile still maps its original binary.
    let mapped = ^lsof -a -p $client.pid -d txt -Fn | complete
    if $mapped.exit_code != 0 { return false }
    $mapped.stdout | lines | any {|path|
        ($path | str starts-with 'n/nix/store/') and (
            ($path | str contains $"-t3code-desktop-($version)/")
            or ($path | str contains $"-t3code-desktop-($version)-extracted/")
        )
    }
}

def server-pid [settings: record] {
    if $settings.darwin {
        let result = ^($settings.serviceCommand) list org.nixos.t3code | complete
        if $result.exit_code != 0 { return null }
        $result.stdout | parse --regex '"PID" = (?<pid>\d+);' | get -o 0.pid | default 0 | into int
    } else {
        let result = ^($settings.serviceCommand) --user show t3code.service --property MainPID --value | complete
        if $result.exit_code != 0 { return null }
        $result.stdout | str trim | into int
    }
}

def healthy [settings: record, target: string] {
    let running = try { open ($settings.state | path join running.json) } catch { return false }
    if $running.generation != $target or $running.pid != (server-pid $settings) { return false }
    let listener = ^lsof -nP -a -p $running.pid -iTCP:3773 -sTCP:LISTEN -t | complete
    if $listener.exit_code != 0 or ($listener.stdout | str trim) != ($running.pid | into string) { return false }
    let result = ^curl --fail --silent --max-time 2 $settings.healthUrl | complete
    if $result.exit_code != 0 { return false }
    let descriptor = try {
        $result.stdout | from json
    } catch { return false }
    $descriptor.serverVersion? == (open ($target | path join share t3code release.json)).version
}

def wait-ready [settings: record, target: string] {
    for attempt in 1..30 {
        if (healthy $settings $target) { return }
        sleep 1sec
    }
    error make {msg: "T3 Code did not become ready. The desktop stays closed; inspect the server logs before retrying t3-activate."}
}

def launch [settings: record, args: list<string>] {
    let target = active $settings
    if $target == null or not (healthy $settings $target) {
        error make {msg: "T3 Code's active server is not ready. Run t3-activate, then reopen the desktop."}
    }
    let existing = desktops
    if ($existing | length) > 1 or ($existing | any {|client| not (desktop-current $client $target) }) {
        error make {msg: "An outdated or duplicate T3 Code desktop is running. Run t3-activate to replace it."}
    }
    ^($settings.spawn) ...$args
    for attempt in 1..30 {
        let clients = desktops
        if ($clients | length) == 1 {
            if (desktop-current $clients.0 $target) { return }
        }
        sleep 1sec
    }
    error make {msg: $"T3 Code desktop did not start. See ($settings.state)/desktop.log."}
}

def activate [settings: record] {
    let target = generation $settings.staged | default (active $settings)
    if $target == null { error make {msg: "No T3 Code release is installed. Run t3-update-now."} }
    let clients = desktops
    let clients_current = ($clients | is-empty) or (
        ($clients | length) == 1 and (desktop-current $clients.0 $target)
    )
    if (active $settings) == $target and (healthy $settings $target) and $clients_current {
        print "T3 Code: the active server and desktop are current."
        return
    }

    print "T3 Code: closing desktop clients..."
    for client in $clients { kill $client.pid }
    for attempt in 1..30 {
        if (desktops | is-empty) { break }
        sleep 1sec
    }
    if (desktops | is-not-empty) {
        error make {msg: "T3 Code desktop did not quit. Activation stopped before changing the server."}
    }

    print "T3 Code: stopping the managed server..."
    if $settings.darwin {
        let domain = $"gui/(^id -u | str trim)"
        let loaded = ^($settings.serviceCommand) print $"($domain)/org.nixos.t3code" | complete
        if $loaded.exit_code == 0 { ^($settings.serviceCommand) bootout $"($domain)/org.nixos.t3code" }
    } else {
        ^($settings.serviceCommand) --user stop t3code.service
    }

    ^nix-env --profile $settings.profile --set $target
    if $settings.darwin {
        ^($settings.serviceCommand) bootstrap $"gui/(^id -u | str trim)" $settings.serviceFile
    } else {
        ^($settings.serviceCommand) --user start t3code.service
    }
    wait-ready $settings $target
    if ($clients | is-not-empty) { launch $settings [] }
    print $"T3 Code: activated (open ($target | path join share t3code release.json) | get version)."
}

def main [settings_file: path, action: string, ...args: string] {
    let settings = open $settings_file
    mkdir ($settings.profile | path dirname)
    match $action {
        stage => {
            let target = $args.0
            # Keep downloaded generations GC-rooted without changing active launches.
            ^nix-env --profile $settings.staged --set $target
        }
        seed => {
            if (generation $settings.profile) == null {
                let target = generation $settings.staged | default $settings.initial
                if $target == null { error make {msg: "No T3 Code bootstrap release is available."} }
                ^nix-env --profile $settings.profile --set $target
            }
        }
        activate => { activate $settings }
        launch => { launch $settings $args }
        _ => { error make {msg: $"Unknown T3 Code lifecycle action: ($action)"} }
    }
}
