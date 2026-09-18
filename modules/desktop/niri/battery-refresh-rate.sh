resolution=$1

sync_refresh_rate() {
  local power_state refresh current target
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

  current=$(niri msg --json outputs | jq -r '
    .["eDP-1"] |
    if .current_mode == null then ""
    else .modes[.current_mode] | "\(.width)x\(.height)@\(.refresh_rate / 1000)"
    end
  ')
  target="$resolution@$refresh"
  # Leave a disabled/disconnected panel alone, and avoid redundant mode changes.
  if [[ -n "$current" && "$current" != "$target" ]]; then
    niri msg output eDP-1 mode "$target"
  fi
}

sync_refresh_rate
# Line buffering delivers power events immediately. The monitor's initial line
# also reconciles changes between the initial check and subscribing to events.
stdbuf -oL upower --monitor | while IFS= read -r _event; do
  sync_refresh_rate
done
