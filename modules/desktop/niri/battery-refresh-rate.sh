resolution=$1

sync_refresh_rate() {
  local power_state refresh output current target vrr_enabled
  power_state=$(busctl --system get-property org.freedesktop.UPower \
    /org/freedesktop/UPower org.freedesktop.UPower OnBattery)
  case "$power_state" in
  'b true') refresh=60 ;;
  'b false') refresh=165.003 ;;
  *)
    echo "Unexpected UPower OnBattery value: $power_state" >&2
    return 1
    ;;
  esac

  output=$(niri msg --json outputs | jq -c '.["eDP-1"]')
  # Leave a disabled/disconnected panel alone.
  if [[ $(jq -r '.current_mode' <<<"$output") == null ]]; then
    return 0
  fi
  current=$(jq -r '.modes[.current_mode] | "\(.width)x\(.height)@\(.refresh_rate / 1000)"' <<<"$output")
  vrr_enabled=$(jq -r '.vrr_enabled' <<<"$output")
  target="$resolution@$refresh"
  # Disable VRR before lowering the mode; enable it after restoring the AC mode.
  if [[ "$power_state" == 'b true' && "$vrr_enabled" == true ]]; then
    niri msg output eDP-1 vrr off
  fi
  if [[ "$current" != "$target" ]]; then
    niri msg output eDP-1 mode "$target"
  fi
  if [[ "$power_state" == 'b false' && "$vrr_enabled" == false ]] &&
    [[ $(jq -r '.vrr_supported' <<<"$output") == true ]]; then
    niri msg output eDP-1 vrr on
  fi
}

sync_refresh_rate
# Line buffering delivers power events immediately. The monitor's initial line
# also reconciles changes between the initial check and subscribing to events.
stdbuf -oL upower --monitor | while IFS= read -r _event; do
  sync_refresh_rate
done
