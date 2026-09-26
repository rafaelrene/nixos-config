def packaged-version [file: path] {
    open --raw $file
    | parse --regex '(?m)^  version = "(?<version>[^"]+)";'
    | get 0.version
}

def main [settings_file: path] {
    let settings = (open $settings_file)
    $env.NIX_CONFIG = "experimental-features = nix-command flakes\naccept-flake-config = false"
    cd $settings.state

    # Preserve the staged version and make old store copies writable.
    for file in [flake.nix package.nix desktop.nix] {
        if not ($file | path exists) {
            cp ($settings.source | path join $file) $file
        }
    }
    ^chmod u+w flake.nix package.nix desktop.nix
    if not (".git" | path exists) { ^git init -q }
    ^git add flake.nix package.nix desktop.nix
    if $settings.refreshInputs {
        ^nix flake update --no-accept-flake-config
    } else if not ("flake.lock" | path exists) {
        ^nix flake lock --no-accept-flake-config
    }
    ^git add flake.lock

    let current = (packaged-version package.nix)
    let desktop_current = (packaged-version desktop.nix)
    print $"T3 Code: checking the nightly channel \(packaged version: ($current)\)..."
    let latest = try {
        let version = ^curl --fail --silent --show-error --retry 3 https://registry.npmjs.org/t3
        | from json
        | get dist-tags.nightly
        if ($version | describe) != string or ($version | is-empty) {
            error make {msg: "The nightly channel did not return a version."}
        }
        $version
    } catch {|error|
        if not $settings.allowFallback { error make {msg: $error.msg} }
        print --stderr $"Could not check the nightly channel; using packaged version ($current)."
        $current
    }

    if $latest != $current or $latest != $desktop_current {
        print $"Updating T3 Code ($current) -> ($latest)"
        try {
            ^nix-update --flake --version $latest t3code-nightly
            ^nix-update --flake --version $latest t3code-desktop
        } catch {
            ^git restore package.nix desktop.nix flake.lock
            if not $settings.allowFallback {
                error make {msg: "T3 Code: update failed; the installed generation is unchanged."}
            }
            print --stderr $"Nightly metadata is not buildable yet; retaining ($current)."
        }
    } else {
        print "T3 Code: no newer nightly found."
    }

    print "T3 Code: building server and desktop (downloads and build logs follow)..."
    let generation = try {
        ^nix build --print-build-logs --no-link --print-out-paths --no-accept-flake-config .#default
        | str trim
    } catch {
        ^git restore package.nix desktop.nix flake.lock
        let installed = (^test -x ($settings.profile | path join bin t3) | complete)
        if not $settings.allowFallback or $installed.exit_code != 0 {
            error make {msg: "T3 Code: build failed; no new generation was installed."}
        }
        print --stderr "Nightly build failed; retaining the installed generation."
        null
    }

    if $generation != null {
        let previous = (
            try {
                ^readlink -f $settings.profile | str trim
            } catch { "" }
        )
        if $generation != $previous {
            mkdir ($settings.profile | path dirname)
            ^nix-env --profile $settings.profile --set $generation
            print "T3 Code: server and desktop staged."
        } else {
            print "T3 Code: server and desktop are already staged."
        }
        ^git add package.nix desktop.nix flake.lock
    }

    if $settings.project != null {
        let marker = $settings.base | path join .nixos-config-registered
        if not ($marker | path exists) {
            ^install -d -m 0700 $settings.base
            ^($settings.profile | path join bin t3) project add $settings.project --base-dir $settings.base
            touch $marker
        }
    }
    print "T3 Code: update check complete. Reopen the desktop after restarting the server."
}
