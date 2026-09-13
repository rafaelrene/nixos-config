#!/bin/sh

# T3Code's ephemeral naming jobs have no transcript.
if ! jq -e '
  (.transcript_path | type == "string" and length > 0)
  and (
    .hook_event_name == "Stop"
    or .hook_event_name == "PermissionRequest"
    or (.hook_event_name == "PreToolUse"
        and (.tool_name == "request_user_input"
             or .tool_name == "request_user_input_async"))
  )
' >/dev/null 2>&1; then
  exit 0
fi

"$HOME/.local/bin/agent-notify" >/dev/null 2>&1 &
exit 0
