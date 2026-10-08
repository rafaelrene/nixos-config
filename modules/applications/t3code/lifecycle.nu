def generation [profile: path] {
    if ($profile | path exists) {
        ^readlink -f $profile | str trim
    } else { null }
}

def active [settings: record] {
    generation $settings.profile | default $settings.initial
}

def process-snapshot [] {

    # Nushell can fail the whole long scan when an unrelated Linux process exits.
    for attempt in 1..5 {
        try {
            return (ps --long)
        } catch {|failure|
            if $failure.msg != 'Error getting process stat' or $attempt == 5 {
                error make {msg: $failure.msg}
            }
        }
        sleep 50ms
    }
}

def desktop-processes [settings: record] {
    let uid = ^id -u | str trim | into int
    let retained = $settings.home | path join Applications '.T3 Code.next.app'
    process-snapshot | where {|p|
        ($p.user_id == $uid
        and ($p.name =~ '^T3 Code \(' or $p.name in [t3code t3code-desktop])
        and ($p.command =~ '/nix/store/.*t3code-desktop' or $p.command =~ '/nix/profiles/t3code/'
            or ($settings.darwin and (
                ($p.command | str contains $settings.desktopApp)
                or ($p.command | str contains $retained)
            ))))
    }
}

def desktops [settings: record] {
    let candidates = desktop-processes $settings | where command !~ ' --type='
    # Electron workers can use the main executable too. Only manage their parent.
    $candidates | where {|p| $p.ppid not-in $candidates.pid }
}

def desktop-current [settings: record, client: record, target: string] {
    if $settings.darwin {
        let result = ^($settings.desktopCommand) $settings.file process-current $target ($client.pid | into string) | complete
        return ($result.exit_code == 0 and ($result.stdout | str trim) == 'true')
    }
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

def wait-stopped [settings: record, service: string, pid] {

    # bootout returns before launchd finishes removing a terminating service.
    for attempt in 1..30 {
        let loaded = ^($settings.serviceCommand) print $service | complete
        if $loaded.exit_code == 113 and ($pid == null or $pid == 0 or (ps | where pid == $pid | is-empty)) {
            return
        }
        if $loaded.exit_code not-in [0 113] {
            error make {msg: $"Cannot inspect the stopping T3 Code service: ($loaded.stderr | str trim)"}
        }
        sleep 1sec
    }
    error make {msg: "T3 Code did not stop. The active profile is unchanged; inspect the server logs before retrying t3-activate."}
}

def request [settings: record, rollback: bool] {
    let name = if $rollback { 't3code-rollback' } else { 't3code-restart' }
    print "T3 Code: waiting for coordinated activation..."
    if $settings.darwin {
        let service = $"gui/(^id -u | str trim)/org.nixos.($name)"
        ^($settings.serviceCommand) kickstart -p $service | ignore
        for attempt in 1..240 {
            let result = ^($settings.serviceCommand) list $"org.nixos.($name)" | complete
            if $result.exit_code != 0 {
                error make {msg: $"Cannot inspect T3 Code activation: ($result.stderr | str trim)"}
            }
            let pid = $result.stdout | parse --regex '"PID" = (?<pid>\d+);' | get -o 0.pid
            if $pid == null {
                let status = $result.stdout | parse --regex '"LastExitStatus" = (?<status>-?\d+);' | get 0.status | into int
                if $status != 0 {
                    error make {msg: $"T3 Code activation failed. See ($settings.home)/.local/state/nix-darwin/t3code-activation.log."}
                }
                print "T3 Code: activation completed."
                return
            }
            sleep 1sec
        }
        error make {msg: "T3 Code activation is still running after four minutes. Inspect the activation log."}
    } else {
        ^($settings.serviceCommand) --user start $"($name).service"
        print "T3 Code: activation completed."
    }
}

def launch [settings: record, args: list<string>] {
    let target = active $settings
    if $target == null or not (healthy $settings $target) {
        error make {msg: "T3 Code's active server is not ready. Run t3-activate, then reopen the desktop."}
    }
    let existing = desktops $settings
    if ($existing | length) > 1 or ($existing | any {|client| not (desktop-current $settings $client $target) }) {
        error make {msg: "An outdated or duplicate T3 Code desktop is running. Run t3-activate to replace it."}
    }
    ^($settings.spawn) ...$args
    for attempt in 1..30 {
        let clients = desktops $settings
        if ($clients | length) == 1 {
            if (desktop-current $settings $clients.0 $target) { return }
        }
        sleep 1sec
    }
    error make {msg: $"T3 Code desktop did not start. See ($settings.state)/desktop.log."}
}

def stop-desktops [processes: table] {
    print "T3 Code: closing desktop clients..."
    # Let the main clients shut down their workers before forcing any survivors.
    for client in ($processes | where {|p| $p.ppid not-in $processes.pid }) {
        kill --quiet $client.pid
    }
    for attempt in 1..5 {
        if (ps | where pid in $processes.pid | is-empty) { return }
        sleep 1sec
    }
    let remaining = ps | where pid in $processes.pid
    if ($remaining | is-not-empty) {
        print "T3 Code: force-stopping unresponsive desktop processes..."
        kill --force --quiet ...$remaining.pid
    }
    for attempt in 1..5 {
        if (ps | where pid in $processes.pid | is-empty) { return }
        sleep 1sec
    }
    error make {msg: "T3 Code desktop did not quit. Activation stopped before changing the server."}
}

# Every journal write reaches disk before its corresponding mutation.
def save-state [settings: record, name: string, value] {
    let file = $settings.state | path join $name
    let temporary = $"($file).tmp"
    $value | to json | save --force $temporary
    ^sync $temporary
    ^mv --force $temporary $file
    ^sync $settings.state
}

def clear-journal [settings: record] {
    rm --force ($settings.state | path join activation.json)
    ^sync $settings.state
}

def desktop-action [settings: record, action: string, target: string] {
    if $settings.darwin {
        ^($settings.desktopCommand) $settings.file $action $target
    }
}

def app-current [settings: record, target: string] {
    if not $settings.darwin { return true }
    let result = ^($settings.desktopCommand) $settings.file current $target | complete
    $result.exit_code == 0 and ($result.stdout | str trim) == 'true'
}

def stop-server [settings: record] {
    if $settings.darwin {
        let domain = $"gui/(^id -u | str trim)"
        let pid = server-pid $settings
        let loaded = ^($settings.serviceCommand) print $"($domain)/org.nixos.t3code" | complete
        if $loaded.exit_code == 0 { ^($settings.serviceCommand) bootout $"($domain)/org.nixos.t3code" }
        wait-stopped $settings $"($domain)/org.nixos.t3code" $pid
    } else {
        ^($settings.serviceCommand) --user stop t3code.service
    }
}

def start-server [settings: record] {
    if $settings.darwin {
        ^($settings.serviceCommand) bootstrap $"gui/(^id -u | str trim)" $settings.serviceFile
    } else {
        ^($settings.serviceCommand) --user start t3code.service
    }
}

def recover [settings: record] {
    let journal = open ($settings.state | path join activation.json)
    print "T3 Code: restoring the previous release after an incomplete activation..."
    # Reuse the retained complete desktop when possible. Never start an older
    # server alongside a newer desktop, or erase a journal before recovery works.
    desktop-action $settings prepare $journal.previous
    stop-desktops (desktop-processes $settings)
    stop-server $settings
    ^nix-env --profile $settings.profile --set $journal.previous
    desktop-action $settings install $journal.previous
    start-server $settings
    wait-ready $settings $journal.previous
    desktop-action $settings dock $journal.previous
    if $journal.reopen { launch $settings [] }
    ^nix-env --profile $settings.staged --set $journal.previous
    if $journal.target != $journal.previous {
        save-state $settings blocked.json $journal.target
    }
    clear-journal $settings
    print "T3 Code: the previous release is running. Database files were left untouched."
}

def activate [settings: record, rollback: bool] {
    let previous = active $settings
    let target = if $rollback {
        generation $settings.previous
    } else {
        generation $settings.staged | default $previous
    }
    if $target == null { error make {msg: "No T3 Code release is available for this operation."} }
    let blocked = try { open ($settings.state | path join blocked.json) } catch { null }
    if $target == $blocked {
        error make {msg: "This T3 Code generation failed or was rolled back. Stage a different release before activating it."}
    }
    let processes = desktop-processes $settings
    let clients = desktops $settings
    let clients_current = ($processes | is-empty) or (
        ($clients | length) == 1 and (desktop-current $settings $clients.0 $target)
    )
    if $previous == $target and (healthy $settings $target) and $clients_current and (app-current $settings $target) {
        desktop-action $settings dock $target
        print "T3 Code: the active server and desktop are current."
        return
    }
    if $previous == null { error make {msg: "No previous T3 Code release exists. Bootstrap it before activation."} }

    # Copy and verify before interrupting the working app. Retain the old Nix
    # release as a GC root before recording a recoverable activation intent.
    desktop-action $settings prepare $target
    if $target != $previous {
        ^nix-env --profile $settings.previous --set $previous
    }
    save-state $settings activation.json {
        previous: $previous
        target: $target
        reopen: ($clients | is-not-empty)
    }
    try {
        stop-desktops $processes
        if (desktop-processes $settings | is-not-empty) {
            error make {msg: "A T3 Code desktop appeared during shutdown."}
        }
        print "T3 Code: stopping the managed server..."
        stop-server $settings
        ^nix-env --profile $settings.profile --set $target
        desktop-action $settings install $target
        start-server $settings
        wait-ready $settings $target
        desktop-action $settings dock $target
        if ($clients | is-not-empty) { launch $settings [] }
        if $rollback {
            ^nix-env --profile $settings.staged --set $target
            if $previous != $target { save-state $settings blocked.json $previous }
        }
        clear-journal $settings
    } catch {|failure|
        try {
            recover $settings
        } catch {|recovery| error make {msg: $"Activation failed: ($failure.msg). Recovery also failed: ($recovery.msg). The previous release and recovery journal are retained; retry t3-activate."} }
        error make {msg: $"Activation failed: ($failure.msg). The previous release was restored."}
    }
    print $"T3 Code: activated (open ($target | path join share t3code release.json) | get version)."
}

def main [settings_file: path, action: string, ...args: string] {
    let settings = open $settings_file | insert file $settings_file
    mkdir ($settings.profile | path dirname)
    match $action {
        stage => {
            let target = $args.0
            let blocked = try { open ($settings.state | path join blocked.json) } catch { null }
            if $target == $blocked {
                error make {msg: "This T3 Code generation failed or was rolled back; leaving the working release installed."}
            }
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
        request => { request $settings false }
        request-rollback => { request $settings true }
        activate | rollback | launch => {
            try {
                if ($settings.state | path join activation.json | path exists) { recover $settings }
                if $action == launch { launch $settings $args } else { activate $settings ($action == rollback) }
            } catch {|error|
                let message = $"T3 Code: ($error.msg)"
                let log = if $action == launch { "desktop.log" } else { "activation.log" }
                $"(date now | format date '%Y-%m-%d %H:%M:%S') ($message)\n"
                | save --append ($settings.state | path join $log)
                ^$settings.notifyCommand $message | complete | ignore
                error make {msg: $error.msg}
            }
        }
        _ => { error make {msg: $"Unknown T3 Code lifecycle action: ($action)"} }
    }
}
