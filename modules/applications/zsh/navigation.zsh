# Selection uses numeric indices; labels never become shell commands.
workstation_nav() {
	emulate -L zsh
	setopt localoptions pipefail
	local code_root=${1:A} directory repository marker label selection index
	local -a kinds names locations repositories markers roots
	local -A seen

	for label directory in Home "$HOME" Code "$code_root" Config "$HOME/.config"; do
		[[ -d $directory ]] || continue
		kinds+=(directory)
		names+=("$label")
		locations+=("$directory")
	done
	if [[ -d $code_root ]]; then
		markers=("${(@0)$(command fd --hidden --no-ignore --prune --type d --type f --glob .git \
			--absolute-path --print0 --exclude node_modules --exclude vendor --exclude target \
			--exclude dist --exclude build --exclude .devenv \
			--exclude .cache --exclude .opencode "$code_root")}") || return
		for marker in "${markers[@]}"; do
			[[ -n $marker ]] && repositories+=("${marker:h}")
		done
		for repository in "${(@ou)repositories}"; do
			for directory in "${roots[@]}"; do
				[[ $repository == "$directory/"* ]] && continue 2
			done
			roots+=("$repository")
			kinds+=(project)
			names+=("${repository#"$code_root/"}")
			locations+=("$repository")
		done
	fi
	for directory in "$HOME/.config"/*(ND/); do
		kinds+=(config)
		names+=("Config / ${directory:t}")
		locations+=("$directory")
	done
	for directory in othinus proserpina; do
		kinds+=(ssh)
		names+=("$directory")
		locations+=("$directory")
	done

	local rows=''
	for (( index=1; index<=${#locations}; index++ )); do
		[[ -n ${seen["${kinds[index]}:${locations[index]}"]-} ]] && continue
		seen["${kinds[index]}:${locations[index]}"]=1
		label="${names[index]}  ·  ${kinds[index]}  ·  ${locations[index]}"
		label=${label//[[:cntrl:]]/ }
		rows+="$index"$'\t'"$label"$'\0'
	done
	selection=$(print -rn -- "$rows" | command fzf --read0 --print0 --delimiter $'\t' \
		--with-nth 2.. --nth 1.. --layout reverse --no-multi --no-select-1 --no-exit-0 \
		--prompt 'Destination > ' --header 'Enter: cd / ssh   Esc: cancel')
	local result=$?
	(( result == 1 || result == 130 )) && return 0
	(( result == 0 )) || return $result
	index=${selection%%$'\t'*}
	[[ $index == <-> ]] && (( index >= 1 && index <= ${#locations} )) || return 1
	if [[ ${kinds[index]} == ssh ]]; then
		command ssh "${locations[index]}"
	else
		builtin cd -- "${locations[index]}"
	fi
}
