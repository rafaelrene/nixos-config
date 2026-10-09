# Keep history writable and use the same Vi leader in every terminal.
mkdir -p -- "${HISTFILE:h}"
bindkey -v
KEYTIMEOUT=10

cdb() { builtin cd -- "${1:-.}"; }

source @git-worktrees@
source @git-nav@
source @navigation@

nav() { workstation_nav @code-root@; }

# Dispatch the shell-only command while retaining Git's external subcommands.
git() {
	if [[ ${1-} == nav ]]; then
		shift
		git_nav "$@"
	else
		command git "$@"
	fi
}

ns() {
	local checkout=${1:-@checkout@}
	checkout=${checkout:A}

	# Git's flake source excludes ignored local development state.
	sudo @rebuild@ switch --flake "$checkout#"@hostname@ || return
	local activate=/nix/var/nix/profiles/system/sw/bin/t3-activate
	if [[ -x $activate ]]; then
		"$activate"
	else
		print -u2 -- "System switch completed from $checkout. This configuration has no t3-activate; T3 Code activation was skipped."
	fi
}

nup() {
	local checkout=${1:-@checkout@}
	nix-update-packages "${checkout:A}"
}

nups() {
	local checkout=${1:-@checkout@}
	nix-update-packages "${checkout:A}" --stage-t3 || return
	ns "$checkout"
}

# Read menu keys while ZLE owns the terminal; suspend it only for the picker.
workstation_leader_widget() {
	local key
	local -a action
	zle -R 'Space: nav   g: git   Esc: cancel'
	read -rk1 key || return
	case $key in
		' ') action=(nav) ;;
		g)
			zle -R 'n: git nav   r: project-run   d: delete branches   Esc: cancel'
			read -rk1 key || return
			case $key in
				n) action=(git_nav) ;;
				r) action=(command project-run) ;;
				d) action=(command git-delete-branches) ;;
			esac
			;;
	esac
	(( ${#action} )) || return 0

	zle -I
	# Widgets inherit /dev/null as stdin; interactive commands need the terminal.
	"${action[@]}" </dev/tty
	# A picker changes directories without starting a new prompt cycle.
	if (( $+functions[_devenv_trust_t3] )); then
		_devenv_trust_t3
	fi
	if (( $+functions[_devenv_hook] )); then
		_devenv_hook
	fi
	zle reset-prompt
}
zle -N workstation-leader workstation_leader_widget
bindkey -M vicmd ' ' workstation-leader
