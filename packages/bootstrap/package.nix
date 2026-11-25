{
  lib,
  stdenv,
  writeShellApplication,
  coreutils,
  gnugrep,
  git,
  jq,
  nix,
  nixos-anywhere,
  openssh,
  sops,
  yq-go,
}:
writeShellApplication {
  name = "bootstrap";
  runtimeInputs = [
    coreutils
    gnugrep
    git
    jq
    nix
    nixos-anywhere
    openssh
    sops
    yq-go
  ];
  text = builtins.readFile ./bootstrap.sh;

  # Every refusal that needs no flake evaluation runs here, before any key,
  # recipient or disk is touched.
  derivationArgs.postCheck = ''
    export HOME=$(mktemp -d) TMPDIR=$(mktemp -d) PATH=${lib.makeBinPath [ git ]}:$PATH
    refuses() {
      local want="$1"; shift
      if out=$("$target" "$@" 2>&1 </dev/null); then
        echo "expected failure: bootstrap $*" >&2; exit 1
      fi
      if ! grep -q -- "$want" <<<"$out"; then
        echo "bootstrap $*: expected '$want', got: $out" >&2; exit 1
      fi
      for left in "$TMPDIR"/bootstrap.*; do
        echo "bootstrap $*: left $left behind" >&2; exit 1
      done
    }

    # Reachability comes before the identity: a wrong address or an
    # installed host must not leave a new key or re-keyed secrets behind.
    reaches_preflight() {
      refuses "cannot reach root@127.0.0.1\\|looks installed" nixos h 127.0.0.1
      [ ! -e secrets/hosts/h.pub ] || { echo "preflight left an identity behind" >&2; exit 1; }
    }

    refuses Usage
    refuses Usage nixos
    refuses Usage nixos h
    refuses Usage darwin
    refuses "unknown platform" freebsd h
    ${if stdenv.hostPlatform.isDarwin then "" else "refuses macOS darwin old"}

    cd "$(mktemp -d)"
    refuses "run inside the repository" nixos h 1.2.3.4

    git init -q repo && cd repo
    mkdir -p secrets/hosts
    touch flake.nix .sops.yaml
    echo "ssh-ed25519 AAAA root@old" > secrets/hosts/old.pub
    printf 'a: 1\nsops:\n  pgp: old\n' > secrets/nixos.yaml
    git add -A
    git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm init

    refuses "--new-key" nixos old 1.2.3.4
    reaches_preflight
    ${lib.optionalString stdenv.hostPlatform.isDarwin "refuses terminal darwin old --new-key"}

    # What an interrupted run leaves behind is not in the way of a rerun.
    echo x >> .sops.yaml
    reaches_preflight

    printf 'a: 1\nsops:\n  pgp: new\n' > secrets/nixos.yaml
    reaches_preflight

    printf 'a: 2\nsops:\n  pgp: new\n' > secrets/nixos.yaml
    refuses "uncommitted changes" nixos h 1.2.3.4

    git checkout -q -- secrets
    echo "b: 1" > secrets/other.yaml
    refuses "uncommitted changes" nixos h 1.2.3.4
  '';

  meta.description = "Install a host, or adopt a Mac, with its SSH identity kept in the repo";
}
