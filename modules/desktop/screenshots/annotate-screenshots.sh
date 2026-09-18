# Niri copies the image before announcing a completed capture. Cancelled
# selections emit no event. Ignore captures explicitly saved by other tools.
niri msg --json event-stream \
  | jq --unbuffered -c 'select(has("ScreenshotCaptured") and .ScreenshotCaptured.path == null)' \
  | while IFS= read -r _event; do
    # Read each capture immediately, even while an earlier editor is still open.
    wl-paste --type image/png | satty --config "$SATTY_CONFIG" --filename - &
  done
