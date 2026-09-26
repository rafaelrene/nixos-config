# These vendors overwrite download URLs. Inspect both complete app payloads
# before publishing their versions and hashes together.
def --wrapped checked [command: string, ...args: string] {
    let result = run-external $command ...$args | complete
    if $result.exit_code != 0 {
        error make {msg: $"($command) failed: ($result.stderr | str trim)"}
    }
    $result.stdout
}

def main [checkout: string] {
    let sources = $checkout | path join "modules/darwin/vendor-sources.json"
    let manifest = (open $sources)
    let workspace = (mktemp --directory)

    try {
        let downloads = ([
      [name extension];
      [google-drive dmg]
      [viber zip]
    ] | each {|app|
      checked nix store prefetch-file --refresh --json --name $"($app.name).($app.extension)" ($manifest | get $app.name | get url)
      | from json
      | insert name $app.name
    })

        let google = $downloads | where name == google-drive | first
        let viber = $downloads | where name == viber | first
        let google_pkg = $workspace | path join "GoogleDrive.pkg"
        ^7zz e -so $google.storePath "Install Google Drive/GoogleDrive.pkg" out> $google_pkg
        let google_version = (
      checked 7zz e -so $google_pkg GoogleDrive_arm64.pkg/PackageInfo
      | from xml | get content | where tag == bundle | get 0.attributes.CFBundleVersion
    )

        let viber_tar = $workspace | path join "Viber.app.tar"
        let viber_plist = $workspace | path join "Info.plist"
        ^unzip -p $viber.storePath Viber.app.tar out> $viber_tar
        ^bsdtar -xOf $viber_tar ./Viber.app/Contents/Info.plist out> $viber_plist
        let viber_version = (
            (checked
                plutil
                -extract
                CFBundleShortVersionString
                raw
                -o
                -
                $viber_plist
            )
            | str trim
        )

        for version in [$google_version $viber_version] {
            if $version !~ '^\d+(\.\d+)+$' {
                error make {msg: $"Invalid vendor package version: ($version)"}
            }
        }

        let updated = ($manifest
      | update google-drive.version $google_version
      | update google-drive.hash $google.hash
      | update viber.version $viber_version
      | update viber.hash $viber.hash)
        if $updated != $manifest {
            # Rename beside the destination to stay atomic across filesystems.
            let staged = (
                mktemp --tmpdir-path ($sources | path dirname) "vendor-sources.json.XXXXXX"
            )
            try {
                $"($updated | to json --indent 2)\n" | save --force $staged
                ^chmod 644 $staged
                mv --force $staged $sources
            } catch {|err|
                rm --force $staged
                error make $err
            }
            rm --force $staged
        }
        print $"Pinned Google Drive ($google_version) and Viber ($viber_version)."
    } catch {|err|
        rm --recursive --force $workspace
        error make $err
    }
    rm --recursive --force $workspace
}
