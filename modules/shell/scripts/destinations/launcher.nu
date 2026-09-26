# Shared destination discovery and Ghostty operations. GUI adapters pass IDs,
# never shell commands. Re-discovery on activation rejects removed destinations.

def directories [root: string] {
  try {
    ls -a $root | where {|entry| ($entry.name | path expand | path type) == dir } | get name | sort
  } catch { [] }
}

def repositories [root: string] {
  if ($root | path type) != dir { return [] }
  # fd handles large source trees without a Nushell pipeline for every folder.
  # It does not follow symlinks. NUL separators preserve spaces and newlines.
  let excluded = [node_modules vendor target dist build .devenv .direnv .cache .opencode]
    | each {|name| [--exclude $name] } | flatten
  let result = (^fd --hidden --no-ignore --prune --type d --type f --glob .git --absolute-path --print0 ...$excluded $root | complete)
  $result.stdout | split row (char nul) | where {|path| $path != "" }
  | each {|path| $path | path dirname | path expand } | uniq | sort
  | reduce --fold [] {|path, roots|
    # A repository's nested repositories belong to git nav, not this picker.
    if ($roots | any {|parent| $path | str starts-with $"($parent)/" }) {
      $roots
    } else { $roots | append $path }
  }
}

def local-destination [kind: string, name: string, directory: string] {
  let path = ($directory | path expand)
  {id: $"($kind):($path)", kind: $kind, name: $name, path: $path}
}

export def destinations [settings: record] {
  let config = ($settings.home | path join .config)
  let roots = [
    (local-destination home Home $settings.home)
    (local-destination code Code $settings.code)
    (local-destination config Config $config)
  ] | where {|row| ($row.path | path type) == dir }
  let projects = (repositories $settings.code | uniq | sort | each {|path|
    local-destination project ($path | path relative-to ($settings.code | path expand)) $path
  })
  let apps = (directories $config | each {|path|
    local-destination config $"Config / ($path | path basename)" $path
  })
  let hosts = ($settings.sshHosts | each {|host|
    {id: $"ssh:($host)", kind: ssh, name: $host, path: $host}
  })
  $roots | append $projects | append $apps | append $hosts | uniq-by id
}

export def matches-directory [destination: record, directory: string] {
  # Ghostty reports an empty directory for some SSH surfaces. Nushell would
  # otherwise resolve that to the launcher's own working directory.
  if not ($directory | str starts-with '/') { return false }
  if ($directory | path type) != dir { return false }
  let path = ($directory | path expand)
  $path == $destination.path or (
    $destination.kind == project and ($path | str starts-with $"($destination.path)/")
  )
}

# A host-qualified prompt title prevents remote shells with the same ~/path
# from being mistaken for a local window. Unrecognized titles are not reusable.
export def title-directory [title: string, hostname: string] {
  let prefix = $"($hostname): "
  if not ($title | str starts-with $prefix) { return null }
  $title | str substring ($prefix | str length)..
}

def existing-terminal [settings: record, destination: record] {
  if $settings.platform == darwin {
    let result = (^/usr/bin/osascript $settings.appleScript list | complete)
    if $result.exit_code != 0 { error make {msg: $result.stderr} }
    $result.stdout | from json | where {|terminal|
      ((title-directory $terminal.title $settings.hostname) != null
      and (matches-directory $destination $terminal.path))
    } | get -o 0.id
  } else {
    let result = (do { ^niri msg --json windows } | complete)
    if $result.exit_code != 0 { return null }
    $result.stdout | from json | where {|window|
      $window.app_id == com.mitchellh.ghostty
    } | sort-by {|window|
      (($window.focus_timestamp.secs? | default 0) * 1_000_000_000
      + ($window.focus_timestamp.nanos? | default 0))
    } | reverse | where {|window|
      let directory = (title-directory ($window.title | default "") $settings.hostname)
      $directory != null and (matches-directory $destination $directory)
    } | get -o 0.id
  }
}

def activate [settings: record, destination: record, force_new: bool] {
  if $destination.kind != ssh and not $force_new {
    let existing = (existing-terminal $settings $destination)
    if $existing != null {
      let result = if $settings.platform == darwin {
        ^/usr/bin/osascript $settings.appleScript focus ($existing | into string) | complete
      } else {
        ^niri msg action focus-window --id ($existing | into string) | complete
      }
      # The window may have closed between discovery and selection.
      if $result.exit_code == 0 { return }
    }
  }
  if $settings.platform == darwin {
    let result = (^/usr/bin/osascript $settings.appleScript new $destination.kind $destination.path $settings.ssh | complete)
    if $result.exit_code != 0 { error make {msg: $result.stderr} }
  } else {
    let args = if $destination.kind == ssh {
      [$"--working-directory=($settings.home)" $"--title=SSH: ($destination.path)" -e $settings.ssh $destination.path]
    } else {
      [$"--working-directory=($destination.path)"]
    }
    # Ghostty's explicit IPC action honors per-window directory/command overrides.
    let remote = (^ghostty +new-window ...$args | complete)
    if $remote.exit_code == 0 { return }
    # On cold start Niri owns the process so the picker can exit immediately.
    let result = (^niri msg action spawn -- $settings.ghostty --gtk-single-instance=true ...$args | complete)
    if $result.exit_code != 0 { error make {msg: $result.stderr} }
  }
}

def pick [settings: record] {
  if $settings.platform == darwin {
    ^/usr/bin/open raycast://extensions/rene/workstation-destinations/destinations
    return
  }
  let rows = (destinations $settings | each {|destination|
    let label = $"($destination.name)  ·  ($destination.kind)  ·  ($destination.path)"
    [{destination: $destination, force_new: false, label: $label}]
    | append (if $destination.kind == ssh { [] } else {
      [{destination: $destination, force_new: true, label: $"Open new window · ($label)"}]
    })
  } | flatten | enumerate | each {|item|
    let label = ($item.item.label | str replace -ar '[\r\n\t]' ' ' | str trim)
    # Pinned Vicinae returns text. A unique prefix disambiguates identical labels.
    $item.item | update label $"($item.index + 1) · ($label)"
  })
  let labels = ($rows | get label | str join (char nl))
  let result = ($labels | ^vicinae dmenu --placeholder 'Open destination…' --no-quick-look | complete)
  if $result.exit_code != 0 or ($result.stdout | str trim | is-empty) { return }
  let row = ($rows | where label == ($result.stdout | str trim) | get -o 0)
  if $row == null { return }
  activate $settings $row.destination $row.force_new
}

def main [settings_file: path, operation: string = pick, id?: string, --new-window] {
  let settings = (open $settings_file)
  match $operation {
    list => { destinations $settings | to json }
    pick => { pick $settings }
    open => {
      let destination = (destinations $settings | where id == $id | get -o 0)
      if $destination == null { error make {msg: 'Destination no longer exists. Refresh the picker.'} }
      activate $settings $destination $new_window
    }
    _ => { error make {msg: 'Use workstation-open [list | pick | open ID [--new-window]]'} }
  }
}
