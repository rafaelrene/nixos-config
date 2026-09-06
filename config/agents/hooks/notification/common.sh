#!/bin/sh

# SSH sessions share the logged-in user's notification service. No desktop
# means there is nothing to notify; never hold up an agent waiting for one.
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[ -S "$runtime_dir/bus" ] || exit 0
export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"

timeout 3 notify-send --app-name=Agent --icon=dialog-information \
  "Agent" "Agent needs attention" >/dev/null 2>&1 || true
