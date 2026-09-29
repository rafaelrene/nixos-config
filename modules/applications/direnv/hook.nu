# Nushell sessions started over SSH can miss the environment from /etc/profile.
$env.DIRENV_CONFIG = "/etc/direnv"

# Check before every prompt so edits reload without changing directories.
$env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt? | default [] | append {||
  let changes = (^direnv export json | from json | default {})
  for entry in ($changes | transpose key value) {
    if $entry.value == null {
      # load-env would leave a null-valued entry instead of removing the variable.
      hide-env -i $entry.key
    } else if $entry.key == "PATH" {
      $env.PATH = ($entry.value | split row (char esep))
    } else {
      load-env {($entry.key): $entry.value}
    }
  }
})
