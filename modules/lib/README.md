# lib/

Functions only, no data.

- `flake-lib.nix` declares `flake.lib`, so several files can add to it.
- `builders.nix`:
  - `config.builders.{nixos,darwin} system module` (internal). It builds a system on `perSystem`'s nixpkgs with all `plumbing` included. `../nix/hosts.nix` builds the hosts with it.
  - `config.builders.{testNixos,testDarwin} module`, the same for eval tests.

A helper from `master`'s `lib/` (`net`, `identity`, `openvpn`, `terraform`, …) comes back here only when a feature needs it. Put it in a file named after it, as `flake.lib.<name>`. Data from `lib/defaults` goes to `../constants/` instead.

Rules: [../README.md](../README.md).
