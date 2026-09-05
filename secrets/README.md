# SSH key bundle

`ssh-keys.age` contains the three SSH private keys encrypted together using
age's passphrase mode. There is no separate age identity file.

The first interactive `sudo nixos-rebuild switch --flake .#othinus` creates the
bundle from `/data/code/ansible/roles/ssh/files` if it is missing. Age prompts
for a new passphrase and confirmation in your terminal. Commit the resulting
`secrets/ssh-keys.age`; the plaintext source is never copied into this checkout.
On another machine, the same rebuild prompts to decrypt the committed bundle.

The switch checks the bundle digest and installed file digests. Unchanged keys
need no prompt. A changed bundle or missing/modified installed key triggers
decryption. Decrypted keys live in `/home/raf/.ssh` with mode 0600, outside the
Nix store. Intermediate plaintext is restricted to a private temporary directory
in `/dev/shm` and removed on exit. This machine's disks are unencrypted, as
specified in ADR 0004; installed keys have no additional disk encryption.

Existing SSH-key passphrases are preserved. In particular, the personal key has
its own passphrase, independent of the archive passphrase. The SSH agent caches
unlocked identities for the login session.

The SSH config selects `/run/user/1000/ssh-agent` explicitly, so existing
applications also use the NixOS agent. To unlock the personal key for T3Code,
run `env SSH_AUTH_SOCK=/run/user/1000/ssh-agent ssh-add ~/.ssh/personal` locally.
No T3Code restart is needed. GitHub's verified host key is declared in NixOS
so background pushes can verify the server without an interactive trust prompt.

The hook runs for `switch` and `test`, not boot or build. It requires the `raf`
account to exist (as on this machine). A terminal is required only when keys
need encryption/decryption. Cancelling or entering a wrong passphrase fails the
pre-switch check before replacing installed keys. Do not bypass that check with
`NIXOS_NO_CHECK=1`. For remote deployment, run the rebuild in an interactive SSH
terminal on the target.

SSH configuration is an editable symlink to
`/data/code/nixos-config/config/ssh/config`. An existing different config is
preserved alongside it as `config.before-nixos-<unique suffix>`. Existing private
keys with different contents are similarly backed up before replacement. All
backups stay inside the private SSH directory; delete them when no longer needed.

To replace the bundle, first move the current ciphertext to a safe location
outside the checkout, update the Ansible source keys and the matching public
keys in `config/ssh`, then rebuild and commit the new ciphertext and public keys.
Changing the archive passphrase cannot revoke old ciphertext in Git history;
rotate the SSH keys themselves if the old passphrase is compromised.

Use a strong, unique passphrase. Type it only in the local prompt, never in a
command argument, Nix expression, environment variable, or chat message.
