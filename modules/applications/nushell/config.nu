$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.XDG_CONFIG_HOME = ($env.HOME | path join ".config")
$env.XDG_CACHE_HOME = ($env.HOME | path join ".cache")
$env.XDG_DATA_HOME = ($env.HOME | path join ".local" "share")
$env.XDG_STATE_HOME = ($env.HOME | path join ".local" "state")
$env.CODEX_HOME = ($env.XDG_DATA_HOME | path join "codex")
$env.CLAUDE_CONFIG_DIR = ($env.XDG_DATA_HOME | path join "claude")
$env.T3CODE_HOME = ($env.XDG_DATA_HOME | path join "t3code")
$env.STARSHIP_CONFIG = ($env.XDG_CONFIG_HOME | path join "starship" "starship.toml")

# `cdb` is the direct built-in escape hatch when zoxide's `cd` behavior is not
# wanted for one directory change.
def --env cdb [path: path = "."] {
  cd ($path | path expand)
}

# Bind navigation to the built-in cd before zoxide replaces it.
use @git-nav@ *
use @nav@ nav
source @zoxide-hook@
source @direnv-hook@
source @starship-hook@

def --env shell-leader [] {
  print 'Space: nav   n: git nav   p: project-run   Esc: cancel'
  let key = input listen --types [key]
  if $key.key_type != char or ($key.modifiers | is-not-empty) { return }
  match $key.code {
    ' ' => { nav }
    'n' => { git nav }
    'p' => { ^project-run }
    _ => {}
  }
}

# Execute at the prompt, preserving any partially typed command.
$env.config.keybindings = ($env.config.keybindings | append {
  name: shell_leader
  modifier: none
  keycode: space
  mode: vi_normal
  event: {send: executehostcommand, cmd: shell-leader}
})

# Nushell may start without the PATH configured by /etc/profile.
$env.PATH = ($env.PATH | prepend ($env.HOME | path join ".local" "bin") | uniq)

alias ls = eza -la --icons=auto --group-directories-first
alias gs = git status
alias gf = git fetch
alias gp = git merge --ff-only --autostash '@{upstream}'
alias gl = git log --graph --color=auto --pretty=tformat:'%C(yellow)%h%C(reset) %C(green)%d%C(reset) %s %C(dim white)(%ar) <%an>%C(reset)'
alias gll = git log --color=auto --date=format:'%Y-%m-%d %H:%M' --pretty=tformat:'%C(yellow)%H%C(reset) %C(green)%D%C(reset)%n%C(dim white)%ad  %an%C(reset)%n%n    %C(bold)%s%C(reset)%n%n%w(0,4,4)%b%w(0,0,0)%n'
alias vim = nvim
alias v = nvim
alias fg = job unfreeze
alias pn = pnpm

# Use the configured checkout unless a worktree path is supplied.
def ns [path: path = @checkout@] {
  let checkout = ($path | path expand)
  @rebuild-command@ --flake $"path:($checkout)#@hostname@"
  # Resolve from the new system, not this shell's previously generated configuration.
  let activate = '/nix/var/nix/profiles/system/sw/bin/t3-activate'
  if ($activate | path exists) {
    ^$activate
  } else {
    print --stderr $"System switch completed from ($checkout). This configuration has no t3-activate; T3 Code activation was skipped."
  }
}

def nup [path: path = @checkout@] {
  @update-command@ ($path | path expand)
}

# Update packages, then switch only after a successful update.
def nups [path: path = @checkout@] {
  @update-command@ ($path | path expand) --stage-t3
  ns $path
}
