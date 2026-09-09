$env.config.show_banner = false
$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.NH_FLAKE = "/data/code/nixos-config"
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

source @zoxide-hook@
source @devenv-hook@
source @starship-hook@

alias ls = eza -la --icons=auto --group-directories-first
alias gs = git status
alias gf = git fetch
alias vim = nvim
alias v = nvim
alias pn = pnpm
