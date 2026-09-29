def fetch [url: string] {
    http get --raw --max-time 60sec --headers {Cache-Control: no-cache} $url
}

def stable-version [version: string] {
    if $version !~ '^\d+\.\d+\.\d+$' {
        error make {msg: $"Invalid stable release version: ($version)"}
    }
    $version
}

def checksum [hash: string] {
    if $hash !~ '^[a-f0-9]{64}$' {
        error make {msg: "Missing or invalid publisher SHA-256 checksum."}
    }
    $hash
}

def releases [] {
    let codex = fetch https://releases.openai.com/codex/channels/latest | from json
    let codex_version = stable-version ($codex.tag_name | str replace --regex '^rust-v' '')
    let codex_hashes = [
        [system, target];
        [aarch64-darwin, aarch64-apple-darwin]
        [x86_64-linux, x86_64-unknown-linux-musl]
    ] | reduce --fold {} {|platform, hashes|
        let assets = $codex.assets | where name == $"codex-package-($platform.target).tar.gz"
        if ($assets | length) != 1 {
            error make {msg: $"Expected one Codex package for ($platform.target)."}
        }
        let hash = checksum ($assets.0.digest | str replace --regex '^sha256:' '')
        $hashes | insert $platform.system $hash
    }

    let claude_base = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
    let claude_version = stable-version (fetch $"($claude_base)/latest" | str trim)
    let claude = fetch $"($claude_base)/($claude_version)/manifest.json" | from json
    if $claude.version != $claude_version {
        error make {msg: "Claude release manifest does not match its latest version."}
    }
    {
        codex: {version: $codex_version, hashes: $codex_hashes}
        claude-code: {
            version: $claude_version
            hashes: {
                aarch64-darwin: (checksum $claude.platforms.darwin-arm64.checksum)
                x86_64-linux: (checksum $claude.platforms.linux-x64.checksum)
            }
        }
    }
}

def resolved [profile: path] {
    try {
        ^readlink -f $profile | str trim
    } catch { "" }
}

def activate [settings: record] {
    if not ($settings.staged | path exists) {
        print "Agent tools: no staged release."
        return
    }
    let generation = resolved $settings.staged
    if $generation == (resolved $settings.profile) {
        print "Agent tools: already active."
        return
    }
    ^nix-env --profile $settings.profile --set $generation
    print "Agent tools: activated for new sessions."
}

def main [settings_file: path, --stage, --activate] {
    if $stage and $activate {
        error make {msg: "Use either --stage or --activate."}
    }
    let settings = open $settings_file
    if $activate {
        activate $settings
        return
    }

    print "Agent tools: checking the publishers' latest stable releases..."
    let releases = releases
    print $"Agent tools: Codex ($releases.codex.version), Claude Code ($releases.claude-code.version)."
    # Numtide still supplies OpenCode and Claude's platform integration.
    let source = ^nix flake prefetch --refresh --json --no-accept-flake-config $settings.flake | from json
    if $source.storePath !~ '^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._=-]+$' or $source.hash !~ '^sha256-[A-Za-z0-9+/]{43}=$' {
        error make {msg: "Invalid prefetched agent source."}
    }

    # Release values contain only validated versions and hex checksums.
    let expression = $"($settings.bundle) { path = \"($source.storePath)\"; hash = \"($source.hash)\"; releases = builtins.fromJSON ''($releases | to json --raw)''; }"
    let expected = ^nix eval --raw --expr $"\(($expression)\).outPath"
    if $expected != (resolved $settings.staged) {
        print "Agent tools: building Codex, Claude Code and OpenCode..."
        let generation = (
            ^nix build --print-build-logs --no-link --print-out-paths --expr $expression
            | str trim
        )
        mkdir ($settings.staged | path dirname)
        ^nix-env --profile $settings.staged --set $generation
        print "Agent tools: staged."
    } else {
        print "Agent tools: already staged."
    }
    # Bootstrap a missing profile; background checks otherwise only stage.
    if not $stage or not ($settings.profile | path exists) {
        activate $settings
    }
}
