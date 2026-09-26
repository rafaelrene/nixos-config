# Use the same declared environment as nix-darwin's other supported shells.
load-env (open /nix/var/nix/profiles/system/etc/nushell/environment.json)
$env.T3CODE_HOME = ($env.XDG_DATA_HOME | path join "t3code")
$env.TEALDEER_CONFIG_DIR = ($env.XDG_CONFIG_HOME | path join "tealdeer")
$env.TRY_CONFIG_DIR = ($env.XDG_CONFIG_HOME | path join "try-rs")
$env.TRY_PATH = ($env.HOME | path join "code/.personal/.try")
$env.GIT_CONFIG_GLOBAL = ($env.XDG_CONFIG_HOME | path join "git/config")
# Legacy Zsh sessions exported this path; Nushell loads it as the global config.
if ($env.GIT_CONFIG_SYSTEM? | default "") == ($env.XDG_CONFIG_HOME | path join "git/.gitconfig") {
  hide-env GIT_CONFIG_SYSTEM
}
$env.PATH = ($env.PATH | prepend [
  ($env.HOME | path join ".local/bin")
  "/nix/var/nix/profiles/system/sw/bin"
  ($env.XDG_STATE_HOME | path join "nix/profiles/llm-agents/bin")
  "/nix/var/nix/profiles/default/bin"
  ($env.HOME | path join ".orbstack/bin")
] | uniq)
