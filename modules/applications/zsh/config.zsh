mkdir -p -- "${HISTFILE:h}"
bindkey -e

cdb() { builtin cd -- "${1:-.}"; }

