---
name: add-webapp
description: Use when asked to add a URL as a web app launcher in this NixOS repository.
---

# Add a web app

Inputs: URL and app name. Read both from the user's request. Ask only for a
missing or ambiguous input. Accept an app name containing spaces.

Example: URL `http://othinus.local:3773`, app name `T3Code (Othinus)`.

## Add the registry entry

1. Work in the current checkout. Read `AGENTS.md`, the relevant ADRs, and
   `modules/applications/webapps/default.nix`.
2. Require an absolute HTTP or HTTPS URL. Preserve its scheme, host, port,
   path, query, and fragment. If the scheme is missing, ask for it rather
   than guessing. Do not store credentials or access tokens in this public
   repository or the Nix store.
3. Trim the app name and remove an existing trailing ` Webapp` suffix,
   case-insensitively. Store the base name in `name`; the Nix generator
   appends ` Webapp` to every display name.
4. Derive the key from that base name: lowercase it, replace runs outside
   `a-z0-9` with `-`, and trim leading/trailing `-`. For example,
   `T3Code (Othinus)` becomes `t3code-othinus`. If the result is empty, ask
   for a usable name. If that key belongs to another URL, ask how to
   distinguish the apps instead of overwriting it.
5. Check existing entries before adding one. If the URL and base name
   already exist, report the existing launcher without creating a duplicate.
   If the same URL has a different name, ask whether to rename that entry.
6. Add one entry to `apps`, using valid Nix string escaping. Set `keywords`
   to the key's nonempty hyphen-separated words, with duplicates removed.
   Keep the generator, browser, and profile defaults unchanged.

For the example inputs, the entry is:

```nix
t3code-othinus = {
  name = "T3Code (Othinus)";
  url = "http://othinus.local:3773";
  icon = ./icons/t3code.png;
  keywords = [ "t3code" "othinus" ];
};
```

The existing T3Code entry may have additional keywords. Do not rewrite an
existing entry merely to match this example.

## Add the icon

Reuse an appropriate icon already in `modules/applications/webapps/icons/`.
Otherwise, obtain the app's official PNG or SVG from its site or upstream
repository. Prefer a pinned upstream revision when available. Store it as
`icons/<key>.png` or `icons/<key>.svg`, reference it with `icon`, and record
its source, revision if available, and SHA-256 in `icons/README.md`. Preserve
its applicable license or attribution alongside the asset.

If the official icon or its redistribution terms cannot be established,
omit `icon` and report use of the `internet-web-browser` fallback. Do not
require an icon as a third input or add runtime downloads.

## Verify and report

Run from the repository root:

```sh
nix shell --inputs-from . nixpkgs#nixfmt -c nixfmt modules/applications/webapps/default.nix
nix shell --inputs-from . nixpkgs#statix -c statix check modules/applications/webapps
nix shell --inputs-from . nixpkgs#deadnix -c deadnix --fail modules/applications/webapps
git diff --check
nix flake check --no-build
nix build --no-link .#nixosConfigurations.othinus.config.system.build.toplevel
```

Ensure new assets are included in the Git-backed flake source before those
checks. Keep the existing desktop-file validation enabled. Inspect the
built system's `sw/share/applications/webapp-<key>.desktop`: its name must be
`<base name> Webapp`, its URL must be passed as one Helium `--app` argument,
and its icon must resolve. Do not add permanent test files.

Report the display name, URL, desktop filename, icon source or fallback,
and check results. Flag any failed or unrun checks. Do not switch the live
workstation, commit, or push unless the user explicitly authorized it.
Do not duplicate this procedure in README.md.
