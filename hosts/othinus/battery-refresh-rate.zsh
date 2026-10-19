set -euo pipefail
setopt extendedglob

if (($# != 1)); then
	print -u2 -r -- 'Usage: niri-battery-refresh-rate resolution'
	exit 1
fi
resolution=$1

sync_refresh_rate() {
	local power battery output mode current target vrr_enabled vrr_supported
	power=$(busctl --system get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery)
	power=${power##[[:space:]]#}
	power=${power%%[[:space:]]#}
	case "$power" in
	'b true') battery=true ;;
	'b false') battery=false ;;
	*)
		print -u2 -r -- "Unexpected UPower OnBattery value: $power"
		return 1
		;;
	esac
	output=$(niri msg --json outputs | jq -c '."eDP-1"')
	# Leave a disabled/disconnected panel alone.
	if [[ $(jq -r '.current_mode' <<<"$output") == null ]]; then
		return
	fi
	mode=$(jq -ce '.modes[.current_mode]' <<<"$output")
	current=$(jq -r '"\(.width)x\(.height)@\(.refresh_rate / 1000)"' <<<"$mode")
	if $battery; then
		target="$resolution@60"
	else
		target="$resolution@165.003"
	fi
	vrr_enabled=$(jq -r '.vrr_enabled' <<<"$output")
	vrr_supported=$(jq -r '.vrr_supported' <<<"$output")
	# Disable VRR before lowering the mode; enable it after restoring the AC mode.
	if $battery && [[ "$vrr_enabled" == true ]]; then
		niri msg output eDP-1 vrr off
	fi
	if [[ "$current" != "$target" ]]; then
		niri msg output eDP-1 mode "$target"
	fi
	if ! $battery && [[ "$vrr_enabled" == false && "$vrr_supported" == true ]]; then
		niri msg output eDP-1 vrr on
	fi
}

sync_refresh_rate
# Line buffering delivers power events immediately. The initial monitor line
# reconciles changes between the initial check and subscribing to events.
stdbuf -oL upower --monitor | while IFS= read -r event || [[ -n "$event" ]]; do
	sync_refresh_rate
done
