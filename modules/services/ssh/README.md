# SSH key bundle

Use `ssh proserpina` to connect to Proserpina's `rafael` account on the local
network using `~/.ssh/proserpina`. The alias resolves `proserpina.local`, so it
follows the Mac's LAN address without a fixed IP. Proserpina declares Remote
Login and trusts `proserpina.pub` through nix-darwin.

The managed identities are `personal`, `bitbucket_work`, `othinus`, and
`proserpina`. `ssh-keys.age` stores their private keys together using age's
passphrase mode. There is no separate age identity file. Matching public keys
are stored beside the bundle; the provisioner rejects missing, extra, or
mismatched keys before installing anything. Both machines install all four
identities.

An interactive `sudo nixos-rebuild switch --flake .#othinus` or
`sudo darwin-rebuild switch --flake .#Proserpina` decrypts the bundle when the
installed keys need updating. If the bundle is missing, the hook can create it
from all four identities already installed in the target user's `~/.ssh`.
On a new machine, restore the encrypted bundle from Git first.

To add or replace a key, update its installed private key and the matching
public key in this repository, then repack the archive. From the checkout root
on Othinus, run:

```sh
devenv shell -- python3 modules/services/ssh/ssh-keys.py --repack --repo modules/services/ssh --home /home/raf --source /home/raf/.ssh --age /run/current-system/sw/bin/age --script /run/current-system/sw/bin/script --ssh-keygen /run/current-system/sw/bin/ssh-keygen
```

This validates all four installed keys and prompts for the archive passphrase
and confirmation. It does not require the old archive passphrase. The existing
bundle is replaced only after encryption succeeds; cancellation preserves it.
Installed keys, the live SSH config, and the installed-bundle state are left
unchanged. Commit the resulting ciphertext with the matching public keys and
provisioner changes. The next system switch decrypts and installs the new bundle.

The command also works through an interactive `ssh othinus` session. For a
remote one-shot command, use `ssh -t` to allocate a terminal for the prompt.

The switch checks the bundle digest and installed file digests. Unchanged keys
need no prompt. A changed bundle or missing/modified installed key triggers
decryption. Decrypted keys live in `/home/raf/.ssh` on Othinus and
`/Users/rafael/.ssh` on Proserpina with mode 0600, outside the Nix store.
Intermediate plaintext is restricted to a mode-0700 temporary directory and
removed on normal exit or failure. Othinus uses `/dev/shm` (RAM); Proserpina uses
`~/.ssh` on disk because macOS has no `/dev/shm`. An uncatchable termination can
leave temporary files there. Othinus's disks are unencrypted, as specified in
ADR 0004; its installed keys have no additional disk encryption.

Existing SSH-key passphrases are preserved. In particular, the personal key has
its own passphrase, independent of the archive passphrase. The SSH agent caches
unlocked identities for the login session.

On Othinus, the SSH config selects `/run/user/1000/ssh-agent` explicitly, so existing
applications also use the NixOS agent. To unlock the personal key for T3Code,
run `env SSH_AUTH_SOCK=/run/user/1000/ssh-agent ssh-add ~/.ssh/personal` locally.
No T3Code restart is needed. GitHub's verified host key is declared in NixOS
so background pushes can verify the server without an interactive trust prompt.

The NixOS hook runs for `switch` and `test`, not boot or build. It requires the `raf`
account to exist (as on this machine). A terminal is required only when keys
need encryption/decryption. Cancelling or entering a wrong passphrase fails the
pre-switch check before replacing installed keys. Do not bypass that check with
`NIXOS_NO_CHECK=1`. For remote deployment, run the rebuild in an interactive SSH
terminal on the target.

The Darwin hook runs during activation, after existing preflight checks and
before files or services are changed. It runs as `rafael`, uses the native
terminal for age's passphrase prompt, and leaves the SSH config link to
nix-darwin. Builds and `darwin-rebuild check` do not provision keys. The existing
`rafael` account must be present. A failed prompt aborts activation before keys
are replaced; nix-darwin may already have selected the new system profile.

SSH configuration is an editable symlink to
`/data/code/nixos-config/modules/services/ssh/config`. Host and identity settings
live in the included `hosts.config`, also installed as Proserpina's SSH config.
The Linux config selects the NixOS agent; macOS uses its native agent.
On Othinus, tmpfiles enforces mode 0644 on both files during switch and boot.
The checkout's inherited ACLs can make files group-writable again when Git or an
editor replaces them. If SSH reports `Bad owner or permissions` before the next
switch, run `chmod 0644 ~/.ssh/config /data/code/nixos-config/modules/services/ssh/hosts.config`.
An existing different config is
preserved alongside it as `config.before-nixos-<unique suffix>`. Existing private
keys with different contents are similarly backed up before replacement. All
backups stay inside the private SSH directory; delete them when no longer needed.

When rotating the Proserpina key, rebuild the Mac with the matching public key.
nix-darwin supplies it through `/etc/ssh/nix_authorized_keys.d/rafael`; no duplicate
entry in `~/.ssh/authorized_keys` is needed.
Changing the archive passphrase cannot revoke old ciphertext in Git history;
rotate the SSH keys themselves if the old passphrase is compromised.

Use a strong, unique passphrase. Type it only in the local prompt, never in a
command argument, Nix expression, environment variable, or chat message.
