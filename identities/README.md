# Identities

Public key material for each person who has an account on any host, colocated
so that adding someone is a single copy-paste.

Each identity is one folder, referenced by name from
`nix-config.security.identity.name` (which defaults to the account's username).
The `gpg`, `ssh`, and git-signing home modules — plus the hosts'
`authorizedKeys` — all resolve their key material from here.

```
identities/
  <name>/
    gpg.pub.asc   # GPG public key (ASCII-armored)
    gpg.key-id    # GPG key ID exposed as the SSH key (gpg-agent acts as ssh-agent)
    ssh.pub       # SSH public key (the GPG authentication subkey, OpenSSH format)
```

## Adding a person

1. `cp -r identities/alexander identities/<name>`
2. Replace all three files with the new person's public key material.
3. If their account username differs from `<name>` (same human, different
   account — e.g. `oleksandrsy@workbook` reusing `alexander`), set
   `nix-config.security.identity.name = "<name>";` in that home config.

That's it — gpg import, ssh-agent identity, git signing, and host
`authorizedKeys` all pick it up automatically. A person with **no** folder here
(e.g. a child account) simply gets no key material; nothing else needs changing.

> Only **public** material lives here. The private GPG key (the single secret
> root) is imported out-of-band during bootstrap on each machine.
