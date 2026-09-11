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
alias pn = pnpm
alias ns = sudo nixos-rebuild switch --flake "path:/data/code/nixos-config#othinus"
alias nup = nix-update-packages

# Update packages, then switch only after a successful update.
def nups [] {
  nup
  ns
}
