# Identities

Public key material for each person who has an account on any host, colocated
so that adding someone is a single copy-paste.

Each identity is one folder, named by a user's `identity` (which defaults to
the account's username; `modules/security/authorized-keys.nix`). Hosts read
`ssh.pub` from it into the account's SSH `authorizedKeys`. The GPG files are
kept for the home-manager modules (gpg, ssh agent, git signing) that have not
been ported to den yet.

```
identities/
  <name>/
    gpg.pub.asc   # GPG public key (ASCII-armored)
    gpg.key-id    # GPG key ID exposed as the SSH key (gpg-agent acts as ssh-agent)
    ssh.pub       # SSH public key (the GPG authentication subkey, OpenSSH format)
    git.json      # { name, email, githubAccounts }; read by the dev aspects, only needed by users that include them
```

## Adding a person

1. `cp -r identities/alexander identities/<name>`
2. Replace all three files with the new person's public key material.
3. If their account username differs from `<name>` (same human, different
   account), set `identity = "<name>";` on that user's entry,
   `den.hosts.<system>.<host>.users.<user>`.

Host `authorizedKeys` pick it up automatically. Every user on a host needs a
folder with an `ssh.pub` for now: the SSH aspect reads it for each account and
has no fallback for someone without one.

> Only **public** material lives here. The private GPG key (the single secret
> root) is imported out-of-band during bootstrap on each machine.
