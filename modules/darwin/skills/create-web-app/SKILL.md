---
name: create-web-app
description: Use when the user explicitly invokes create-web-app to add a Chromium web-app launcher to Proserpina's nix-darwin configuration.
disable-model-invocation: true
---

# Create a web app

Add a Chromium launcher to `modules/darwin/web-apps/apps.json` in this
repository. Nix generates Raycast scripts from this name-to-URL map.

## Inputs

Require:

- App name
- App URL

Ask for missing inputs.

Normalize the app name:

1. Replace newlines with spaces.
2. Collapse repeated whitespace and trim surrounding whitespace.
3. Append ` Web App` unless it already has that suffix.

The generator replaces `/` with `-` in filenames only. Check that the resulting
filename does not collide with another entry.

Require a complete URL beginning with `http://` or `https://`. Reject malformed
URLs and other schemes. Preserve the accepted URL exactly.

## Add the launcher

Add the normalized name as a JSON key with the URL as its value. Preserve
existing entries. If the name already exists with a different URL, confirm
replacement unless the user already requested it.

Format the JSON, evaluate the Darwin configuration, and build the generated
launcher from `config.workstation.links`. Check the new script with `sh -n`. Follow the repository's
remaining validation requirements.

Raycast reads `~/.local/share/raycast/scripts`, a real directory containing
individual Nix-managed launcher links. A rebuild applies additions and changes.
Report the name, URL, checks, and whether activation remains pending. Activate
only when the user has authorized switching the live system.
