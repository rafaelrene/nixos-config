# Keep history writable and use the same Vi leader in every terminal.
mkdir -p -- "${HISTFILE:h}"
bindkey -v
KEYTIMEOUT=10

cdb() { builtin cd -- "${1:-.}"; }

source @git-worktrees@
source @git-nav@
source @navigation@

nav() { workstation_nav @code-root@; }

project-run() {
	local selected
	if (( $# )); then
		command project-run "$@"
		return $?
	fi
	selected=$(command project-run --print-command) || return
	[[ -n $selected ]] || return 0
	if zle; then
		# Submit a real command, restoring pending text at the next prompt.
		zle .push-line
		BUFFER=$selected
		zle .accept-line
	else
		# Typed invocations also record the resolved command in this shell.
		print -s -- "$selected"
		eval "$selected"
	fi
}

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
	local checkout=@checkout@ upgrade=false checkout_supplied=false positional=false argument
	for argument in "$@"; do
		if ! $positional; then
			case "$argument" in
			-u | --upgrade-packages) upgrade=true; continue ;;
			-h | --help)
				print -r -- 'Usage: ns [-u|--upgrade-packages] [checkout]'
				print -r -- 'Apply system configuration and activate staged coding agents and T3.'
				print -r -- 'With -u, refresh inputs and stage updates first.'
				return 0 ;;
			--) positional=true; continue ;;
			-*) print -u2 -r -- "Unknown option: $argument"; return 2 ;;
			esac
		fi
		if $checkout_supplied || [[ -z $argument ]]; then
			print -u2 -r -- 'Supply at most one nonempty checkout path.'
			return 2
		fi
		checkout=$argument
		checkout_supplied=true
	done
	checkout=${checkout:A}
	if $upgrade; then
		nix-update-packages "$checkout" || return
	fi

	# Git's flake source excludes ignored local development state.
	@nix-github-auth@ sudo --preserve-env=NIX_CONFIG @rebuild@ switch --flake "$checkout#"@hostname@ || return
	local system_bin=/nix/var/nix/profiles/system/sw/bin
	if [[ -x $system_bin/update-llm-agents ]]; then
		"$system_bin/update-llm-agents" --activate || return
	fi
	if [[ -x $system_bin/t3-activate ]]; then
		"$system_bin/t3-activate"
	fi
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
				r)
					zle -I
					project-run </dev/tty
					return $?
					;;
				d) action=(command git-delete-branches) ;;
			esac
			;;
	esac
	(( ${#action} )) || return 0

	zle -I
	# Widgets inherit /dev/null as stdin; interactive commands need the terminal.
	"${action[@]}" </dev/tty
	# Run prompt hooks after ZLE releases the terminal, preserving pending text.
	zle .push-line
	zle .accept-line
}
zle -N workstation-leader workstation_leader_widget
bindkey -M vicmd ' ' workstation-leader
