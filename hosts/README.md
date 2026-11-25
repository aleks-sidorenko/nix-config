# Hosts

Each host's SSH identity, colocated so that a reinstall keeps it. The host's
age key, and with it its SOPS identity, is derived from the public key.

Each host is one folder, named by the host (`den.hosts.<system>.<name>`). The
`sshKeyFile` host option (`modules/den.nix`) loads `ssh.pub`; nothing reads
the folder otherwise.

```
hosts/
  <name>/
    ssh.pub    # ssh_host_ed25519_key.pub, plaintext
    ssh.yaml   # sops: { ssh_host_ed25519_key }, encrypted to the owner's PGP key only
```

## Adding a host

`just bootstrap-nixos <host> <address>` or, on the Mac,
`just bootstrap-darwin <host>` writes both files, regenerates `.sops.yaml` and
re-keys the secrets the host reads ([docs/bootstrap.md](../docs/bootstrap.md)).
Never write them by hand.

> The private key never leaves `ssh.yaml` except into a temporary folder
> during bootstrap, and onto the host itself.
