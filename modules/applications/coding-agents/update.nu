def main [settings_file: path] {
    let settings = open $settings_file
    print "Agent tools: checking Numtide's latest packages..."
    # Prefetch resolves one immutable source without evaluating its nixConfig.
    let source = ^nix flake prefetch --refresh --json --no-accept-flake-config $settings.flake | from json
    if $source.storePath !~ '^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._=-]+$' or $source.hash !~ '^sha256-[A-Za-z0-9+/]{43}=$' {
        error make {msg: "Invalid prefetched agent source."}
    }

    let expression = $"($settings.bundle) { path = \"($source.storePath)\"; hash = \"($source.hash)\"; }"
    let previous = try {
        ^readlink -f $settings.profile | str trim
    } catch { "" }
    let expected = ^nix eval --raw --expr $"\(($expression)\).outPath"
    if $expected == $previous {
        print "Agent tools: already installed."
        return
    }

    print "Agent tools: building Codex, Claude Code and OpenCode..."
    let generation = (
        ^nix build --print-build-logs --no-link --print-out-paths --expr $expression
        | str trim
    )
    mkdir ($settings.profile | path dirname)
    ^nix-env --profile $settings.profile --set $generation
    print "Agent tools: installed."
}
