def prefetch-hash [url: string] {
    ^nix store prefetch-file --json $url | from json | get hash
}

def update [settings: record] {
    print "T3 Code: checking the nightly channel..."
    let version = (
        ^curl --fail --silent --show-error --retry 3 https://registry.npmjs.org/t3
        | from json
        | get dist-tags.nightly
    )
    # These values become Nix string literals as well as release URLs.
    if ($version | describe) != string or $version !~ '^\d+\.\d+\.\d+-nightly\.[0-9.]+$' {
        error make {msg: "The nightly channel returned an invalid version."}
    }

    let metadata = $settings.profile | path join share t3code release.json
    let installed = if ($metadata | path exists) { open $metadata } else { null }
    let release = if $installed != null and $installed.version == $version {
        $installed
    } else {
        let platform = if $settings.darwin { "darwin-arm64" } else { "linux-x64" }
        let desktop = if $settings.darwin { "arm64.zip" } else { "x86_64.AppImage" }
        let url = $"https://github.com/pingdotgg/t3code/releases/download/v($version)"
        print $"T3 Code: downloading server and desktop ($version)..."
        {
            version: $version
            serverHash: (prefetch-hash $"($url)/t3-($version)-($platform).tar.gz")
            desktopHash: (prefetch-hash $"($url)/T3-Code-($version)-($desktop)")
        }
    }
    for hash in [$release.serverHash $release.desktopHash] {
        if $hash !~ '^sha256-[A-Za-z0-9+/]{43}=$' {
            error make {msg: "Invalid T3 Code download hash."}
        }
    }

    let expression = $"($settings.bundle) { version = \"($version)\"; serverHash = \"($release.serverHash)\"; desktopHash = \"($release.desktopHash)\"; }"
    let previous = try {
        ^readlink -f $settings.profile | str trim
    } catch { "" }
    # Also notice recipe changes when the nightly version itself has not changed.
    let expected = ^nix eval --raw --expr $"\(($expression)\).outPath"
    if $expected == $previous {
        print $"T3 Code: server and desktop ($version) are already installed."
        return false
    }

    print $"T3 Code: building server and desktop ($version)..."
    let generation = (
        ^nix build --print-build-logs --no-link --print-out-paths --expr $expression
        | str trim
    )
    mkdir ($settings.profile | path dirname)
    ^nix-env --profile $settings.profile --set $generation
    print $"T3 Code: server and desktop ($version) installed."
    true
}

def main [settings_file: path, --restart, --bootstrap] {
    let settings = open $settings_file
    let server = $settings.profile | path join bin t3
    let changed = if $bootstrap and ($server | path exists) {
        false
    } else {
        try {
            update $settings
        } catch {|error|
            print --stderr $"T3 Code: update failed: ($error.msg)"
            print --stderr "T3 Code: no server restart requested. The update can be retried."
            exit 1
        }
    }

    if $settings.project != null {
        let marker = $settings.base | path join .nixos-config-registered
        if not ($marker | path exists) {
            ^install -d -m 0700 $settings.base
            ^$server project add $settings.project --base-dir $settings.base
            touch $marker
        }
    }

    if $changed and $restart {

        # Bootstrap may need this same lock when the server starts for the first time.
        ^flock -u 9
        print "T3 Code: restarting the server..."
        if $settings.darwin {
            let uid = ^id -u | str trim
            ^($settings.restartCommand) kickstart -k $"gui/($uid)/org.nixos.t3code"
        } else {
            ^($settings.restartCommand) --user restart t3code.service
        }
        print "T3 Code: server restarted. Reopen the desktop to use the new client."
    } else if $changed {
        print "T3 Code: restart the server and reopen the desktop to use the new release."
    }
}
