# Native Devenv trusts individual projects. Preserve automatic trust for T3
# worktrees, then let its own hook handle activation, reload, and deactivation.
_devenv_trust_t3() {
  emulate -L zsh
  if [[ -n "${DEVENV_ROOT:-}" || "${_DEVENV_HOOK_ACTIVATED:-}" == "$PWD" ]]; then
    return 0
  fi

  local directory=${PWD:A} root trusted_root
  for root in @trusted-roots@; do
    [[ -d "$root" ]] || continue
    trusted_root=${root:A}
    # Resolve symlinks before comparing, and exclude sibling directory names.
    if [[ "$directory" == "$trusted_root" || "$directory" == "$trusted_root/"* ]]; then
      while [[ "$directory" == "$trusted_root" || "$directory" == "$trusted_root/"* ]]; do
        if [[ -f "$directory/devenv.nix" ]]; then
          if command devenv hook-should-activate >/dev/null 2>&1; then
            :
          elif (( $? == 2 )); then
            (builtin cd "$directory" && command devenv allow >/dev/null 2>&1)
          fi
          break
        fi
        directory=${directory:h}
      done
      break
    fi
  done
  return 0
}

# Run before the native activation hook and preserve other prompt integrations.
typeset -ag precmd_functions
if (( ! ${precmd_functions[(I)_devenv_trust_t3]} )); then
  precmd_functions=(_devenv_trust_t3 $precmd_functions)
fi
