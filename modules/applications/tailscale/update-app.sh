# Embedded around nix-darwin's application copy, inside a dedicated subshell.
# The app-only commands deliberately run without TAILSCALE_BE_CLI.
tailscale_user_command() {
	launchctl asuser "$tailscale_uid" sudo -H -u "$tailscale_user" -- \
		"$tailscale_timeout" 15 env -u TAILSCALE_BE_CLI "$@"
}

tailscale_status() {
	"$tailscale_timeout" 3 launchctl asuser "$tailscale_uid" sudo -H -u "$tailscale_user" -- \
		env TAILSCALE_BE_CLI=1 \
		"$tailscale_app/Contents/MacOS/Tailscale" status --json
}

tailscale_before_app_copy() {
	local incoming=$1 home=$4 installed_version incoming_version status daemon_version
	tailscale_app=$2
	tailscale_user=$3
	tailscale_jq=$5
	tailscale_timeout=$6
	tailscale_resume=false
	tailscale_reconnect=false

	# Refuse competing distributions; never remove an unmanaged application.
	local other
	for other in /Applications/Tailscale.app "$home/Applications/Tailscale.app"; do
		if [[ -e $other && ! $other -ef $tailscale_app ]]; then
			echo "Tailscale has another installation at $other; resolve it before rebuilding." >&2
			return 1
		fi
	done
	[[ -x $tailscale_app/Contents/MacOS/Tailscale ]] || return 0

	installed_version=$(defaults read "$tailscale_app/Contents/Info.plist" CFBundleVersion)
	incoming_version=$(defaults read "$incoming/Contents/Info.plist" CFBundleVersion)
	tailscale_expected_version=$(defaults read "$incoming/Contents/Info.plist" CFBundleShortVersionString)
	tailscale_uid=$(id -u "$tailscale_user")
	if ! launchctl print "gui/$tailscale_uid" >/dev/null 2>&1; then
		[[ $installed_version == "$incoming_version" ]] && return 0
		echo "Log in as $tailscale_user before upgrading the Tailscale app." >&2
		return 1
	fi

	if status=$(tailscale_status 2>/dev/null); then
		daemon_version=$("$tailscale_jq" -er '.Version | split("-")[0]' <<<"$status")
		tailscale_reconnect=$("$tailscale_jq" -r '.BackendState == "Running"' <<<"$status")
	else
		# An app that is not running can be copied without starting the VPN.
		if ! pgrep -x -u "$tailscale_uid" Tailscale >/dev/null &&
			! pgrep -f '/Contents/MacOS/io[.]tailscale[.]ipn[.]macsys[.]network-extension$' >/dev/null; then
			return 0
		fi
		echo "Cannot read the running Tailscale state; refusing to replace its app." >&2
		return 1
	fi
	if [[ $installed_version == "$incoming_version" && $daemon_version == "$tailscale_expected_version" ]]; then
		return 0
	fi

	# Preserve connected/stopped state even if the application copy fails.
	tailscale_resume=true
	trap 'tailscale_after_app_copy || true' EXIT
	echo "Stopping Tailscale before updating its app and VPN extension..." >&2
	"$tailscale_timeout" 15 env -u TAILSCALE_BE_CLI \
		"$tailscale_app/Contents/MacOS/Tailscale" down-for-update
}

tailscale_after_app_copy() {
	[[ $tailscale_resume == true ]] || return 0
	tailscale_resume=false
	local status attempt
	# On a failed copy, recover the version that is actually still installed.
	tailscale_expected_version=$(defaults read "$tailscale_app/Contents/Info.plist" CFBundleShortVersionString)
	if ! tailscale_user_command "$tailscale_app/Contents/MacOS/Tailscale" rungui; then
		echo "Could not reopen Tailscale after its app update. Open Tailscale manually." >&2
		return 1
	fi

	# The GUI registers and starts the bundled extension asynchronously.
	for ((attempt = 0; attempt < 10; attempt++)); do
		# shellcheck disable=SC2016 # $version is a jq binding.
		if status=$(tailscale_status 2>/dev/null) &&
			"$tailscale_jq" -e --arg version "$tailscale_expected_version" \
				'(.Version // "" | split("-")[0]) == $version' <<<"$status" >/dev/null; then
			if [[ $tailscale_reconnect == true ]]; then
				# No flags: reconnect without changing DNS, routes, exit nodes, or other settings.
				if ! tailscale_user_command env TAILSCALE_BE_CLI=1 \
					"$tailscale_app/Contents/MacOS/Tailscale" up >/dev/null 2>&1; then
					echo "Could not restore Tailscale's connection after its app update. Open Tailscale manually." >&2
					return 1
				fi
			fi
			return 0
		fi
		sleep 1
	done
	# A deferred extension replacement may still permit reconnecting the old VPN.
	if [[ $tailscale_reconnect == true ]]; then
		tailscale_user_command env TAILSCALE_BE_CLI=1 \
			"$tailscale_app/Contents/MacOS/Tailscale" up >/dev/null 2>&1 || true
	fi
	echo "Tailscale's updated VPN extension is not ready. Open Tailscale and approve Network Extensions if prompted." >&2
	echo "If systemextensionsctl list reports a pending reboot, reboot when convenient." >&2
	return 1
}
