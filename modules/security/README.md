# security/

Secrets, keys and authentication.

Features (from `master`), each across the classes it applies to:
- `sops`
- `ssh`
- `gpg`
- `pass`
- `identity` (resolves `identities/<name>/` key material)
- `pam` (darwin)
- `doas` (nixos)
- `yubikey` (nixos)

Examples:
- `nixos/security/sops` + `darwin/security/sops` + `home/security/sops` → `security/sops/`, aspect `sops`.
- `home/security/identity` → `security/identity/`, aspect `identity`.

The SOPS files themselves move to the top-level `secrets/` when their milestone needs them.

Rules: [../README.md](../README.md).
