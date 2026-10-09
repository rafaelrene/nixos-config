# Keep navigation in this shell so changing directories affects the prompt.
git_nav() {
	emulate -L zsh
	setopt localoptions pipefail extendedglob
	local new_window=false
	case ${1-} in
		-w|--new-window) new_window=true; shift ;;
	esac
	if (( $# )); then
		print -u2 -- 'Usage: git nav [-w|--new-window]'
		return 2
	fi
	local root trees main current head local_refs remote_refs submodules parent entries rows
	root=$(git_output "$PWD" rev-parse --show-toplevel && print -rn -- $'\0') || return
	root=${root%$'\n\0'}
	root=${root:A}
	trees=$(git_worktrees "$root" | command jq -s .) || return
	main=$(command jq -jr '.[0].path + "\u0000"' <<< "$trees") || return
	main=${main%$'\0'}
	current=$(command jq -ce --arg root "$root" '.[] | select(.path == $root)' <<< "$trees") || return
	head=$(command jq -r 'if .branch != "" then .branch else .head[0:8] end' <<< "$current") || return
	local_refs=$(git_output "$root" for-each-ref '--format=%(refname:strip=2)%09%(upstream)' refs/heads/ \
		| command jq -Rs 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], upstream: .[1]})') || return
	remote_refs=$(git_output "$root" for-each-ref '--format=%(refname)%09%(refname:strip=3)%09%(symref)' refs/remotes/ \
		| command jq -Rs 'split("\n") | map(select(length > 0) | split("\t") | {ref: .[0], branch: .[1], symbolic: .[2]})') || return
	submodules=$(git_output "$root" ls-files --stage -z \
		| command jq -Rs 'split("\u0000") | map(select(startswith("160000 ")) | split("\t")[1:] | join("\t")) | unique') || return
	parent=$(git_output "$root" rev-parse --show-superproject-working-tree && print -rn -- $'\0') || return
	parent=${parent%$'\n\0'}
	if [[ -z $parent ]]; then
		parent=$(git_output "$main" rev-parse --show-superproject-working-tree && print -rn -- $'\0') || return
		parent=${parent%$'\n\0'}
	fi
	entries=$(command jq -cn --arg root "$root" --arg main "$main" --arg parent "$parent" \
		--argjson trees "$trees" --argjson locals "$local_refs" \
		--argjson remotes "$remote_refs" --argjson submodules "$submodules" '
		($remotes | map(select(.symbolic == "") | select(.branch as $b | $locals | all(.name != $b)) |
			select(.ref as $r | $locals | all(.upstream != $r)))) as $untracked |
		[{kind: "create", name: "+ Create worktree…", path: $main}] +
		($locals | map(. as $branch | ($trees | map(select(.branch == $branch.name))) as $owners |
			{kind: (if ($owners | length) > 0 then "worktree" else "branch" end),
			name: .name, branch: .name, ref: "", path: ($owners[0].path // $main)})) +
		($untracked | map(. as $remote |
			{kind: "branch", name: (if ($untracked | map(select(.branch == $remote.branch)) | length) > 1
				then (.ref | ltrimstr("refs/remotes/")) else .branch end),
			branch: .branch, ref: .ref, path: $main})) +
		($trees | map(select(.branch == "") |
			{kind: "detached", name: ((.path | split("/") | last) + " @ " + .head[0:8]), path: .path})) +
		($submodules | map({kind: "submodule", name: ., path: ($root + "/" + .)})) +
		(if $parent == "" then [] else [{kind: "parent", name: ($parent | split("/") | last), path: $parent}] end)
	') || return
	rows=$(command jq -jr --arg root "$root" --arg main "$main" '
		to_entries[] | .value as $item |
		(if $item.path == $root and ($item.kind == "worktree" or $item.kind == "detached") then "●" else " " end) as $mark |
		(if $item.path == $main and ($item.kind == "worktree" or $item.kind == "detached") then "main" else $item.kind end) as $kind |
		(if $item.path == $root then "." else $item.path end | tojson) as $location |
		"\(.key + 1)\t\($mark) \($item.name)\t\($kind)\t\($location)\u0000"
	' <<< "$entries") || return
	local selection result key index destination kind branch remote target owners
	local -a selected
	selection=$(print -rn -- "$rows" | command fzf --read0 --print0 --delimiter $'\t' \
		--with-nth 2.. --nth 1,2 --layout reverse --wrap --tiebreak begin,index \
		--no-multi --no-select-1 --no-exit-0 --expect ctrl-t --prompt 'Repository > ' \
		--header "${root:t} · $head"$'\n'"Enter: $(if $new_window; then print 'new window'; else print go; fi)   Ctrl+T: new window   Esc: cancel")
	result=$?
	(( result == 1 || result == 130 )) && return 0
	(( result == 0 )) || return $result
	selected=("${(@0)selection}")
	key=${selected[1]}
	index=${selected[2]%%$'\t'*}
	[[ $index == <-> ]] || return 1
	destination=$(command jq -ce --argjson index "$index" '.[$index - 1] // empty' <<< "$entries") || return
	kind=$(command jq -r .kind <<< "$destination") || return
	target=$(command jq -jr '.path + "\u0000"' <<< "$destination") || return
	target=${target%$'\0'}
	case $kind in
		create)
			local starting_commit directory name checked_name
			starting_commit=$(command jq -r .head <<< "$current") || return
			if [[ $starting_commit == 0## ]]; then
				print -u2 -- 'Commit before creating a worktree with git nav.'
				return 1
			fi
			directory="${T3CODE_HOME:-$HOME/.local/share/t3code}/worktrees/${main:t}"
			print -- "New worktree in $directory"
			read -r 'name?Worktree / branch name (empty cancels): ' || return 0
			name=${name##[[:space:]]#}
			name=${name%%[[:space:]]#}
			[[ -n $name ]] || return 0
			checked_name=$(git_output "$root" check-ref-format --branch "$name") || return
			if [[ $checked_name != "$name" ]]; then
				print -u2 -- 'Enter a literal branch name.'
				return 1
			fi
			target="$directory/${name//\//-}"
			if [[ -e $target || -L $target ]]; then
				print -u2 -- "Worktree path already exists: $target"
				return 1
			fi
			git_output "$main" worktree add -b "$name" "$target" "$starting_commit" || return
			;;
		branch|worktree)
			branch=$(command jq -r .branch <<< "$destination") || return
			remote=$(command jq -r .ref <<< "$destination") || return
			owners=$(git_worktrees "$root" | command jq -sjr --arg branch "$branch" '(map(select(.branch == $branch))[0].path // "") + "\u0000"') || return
			owners=${owners%$'\0'}
			if [[ -n $owners ]]; then
				target=$owners
			elif [[ -z $remote ]]; then
				git_output "$main" switch --no-guess "$branch" || return
				target=$main
			else
				git_output "$main" switch --track -c "$branch" "$remote" || return
				target=$main
			fi
			;;
		*)
			local initialized
			initialized=$(git_output "$target" rev-parse --show-toplevel && print -rn -- $'\0') || return
			initialized=${initialized%$'\n\0'}
			if [[ ${initialized:A} != ${target:A} ]]; then
				print -u2 -- 'Initialize the submodule before navigating to it.'
				return 1
			fi
			;;
	esac
	if [[ $new_window == true || $key == ctrl-t ]]; then
		if [[ $OSTYPE == darwin* ]]; then
			/usr/bin/open -na Ghostty --args "--working-directory=$target" --window-save-state=never
		else
			command ghostty +new-window "--working-directory=$target"
		fi
	else
		builtin cd -- "$target"
	fi
}
