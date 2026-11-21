pick() {
	if (( $# > 1 )); then
		print -u2 -- 'Usage: pick [query]'
		return 2
	fi

	local selection
	selection=$(command workstation-picker "$@" </dev/tty) || return
	[[ -n $selection ]] || return 0

	local -a result=("${(@0)selection}")
	case $result[1] in
		cd)
			builtin cd -- "$result[2]" || return
			if zle; then
				zle .push-line
				zle .accept-line
			fi
			;;
		run|edit)
			local directory=$result[2] manager=$result[3] script=$result[4]
			local line="command ${(q)manager} run ${(q)script}"
			if [[ ${directory:A} != ${PWD:A} ]]; then
				line="(builtin cd -- ${(q)directory} && $line)"
			fi
			if zle; then
				# Keep pending text and submit the resolved command through ZLE for history.
				zle .push-line
				BUFFER=$line
				CURSOR=${#BUFFER}
				if [[ $result[1] == run ]]; then zle .accept-line; fi
			elif [[ $result[1] == edit ]]; then
				print -z -- "$line"
			else
				print -s -- "$line"
				eval "$line"
			fi
			;;
	esac
}

workstation_picker_widget() {
	zle -I
	pick
}
zle -N workstation-picker workstation_picker_widget
bindkey -M emacs '^P' workstation-picker
