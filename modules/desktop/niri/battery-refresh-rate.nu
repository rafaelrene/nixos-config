def --wrapped niri [...args: string] {
    let result = (^niri ...$args | complete)
    if $result.exit_code != 0 { error make {
        msg: ($result.stderr | str trim)
    } }
    $result.stdout
}

def sync-refresh-rate [resolution: string] {
    let power = (
        ^busctl --system get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery
        | complete
    )
    if $power.exit_code != 0 { error make {
        msg: ($power.stderr | str trim)
    } }
    let battery = match ($power.stdout | str trim) {
        'b true' => true
        'b false' => false
        $value => { error make {msg: $"Unexpected UPower OnBattery value: ($value)"} }
    }
    let output = niri msg --json outputs | from json | get -o eDP-1
    # Leave a disabled/disconnected panel alone.
    if $output.current_mode? == null { return }
    let mode = $output.modes | get $output.current_mode
    let current = $"($mode.width)x($mode.height)@($mode.refresh_rate / 1000)"
    let target = $"($resolution)@(if $battery { 60 } else { 165.003 })"
    # Disable VRR before lowering the mode; enable it after restoring the AC mode.
    if $battery and $output.vrr_enabled {
        niri msg output eDP-1 vrr off | print
    }
    if $current != $target {
        niri msg output eDP-1 mode $target | print
    }
    if not $battery and not $output.vrr_enabled and $output.vrr_supported {
        niri msg output eDP-1 vrr on | print
    }
}

def main [resolution: string] {
    sync-refresh-rate $resolution
    # Line buffering delivers power events immediately. The initial monitor line
    # reconciles changes between the initial check and subscribing to events.
    ^stdbuf -oL upower --monitor | lines | each { sync-refresh-rate $resolution } | ignore
}
