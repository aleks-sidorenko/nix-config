usage="Usage: bootstrap nixos <host> <address> [--new-key] [-- <nixos-anywhere args>]
       bootstrap darwin <host> [--new-key]"

[ $# -ge 2 ] || die "$usage"
platform="$1"
host="$2"
shift 2
case "$platform" in
nixos)
    [ $# -ge 1 ] || die "$usage"
    address="$1"
    shift
    ;;
darwin)
    [ "$(uname -s)" = Darwin ] || die "bootstrap darwin runs on the Mac itself (macOS)"
    ;;
*) die "unknown platform: $platform (nixos or darwin)" ;;
esac
new_key=
extra=()
while [ $# -gt 0 ]; do
    case "$1" in
    --new-key) new_key=1 ;;
    --)
        shift
        extra=("$@")
        [ "$platform" = nixos ] || die "$usage"
        break
        ;;
    *) die "$usage" ;;
    esac
    shift
done

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run inside the repository"
[ -f "$root/flake.nix" ] && [ -f "$root/.sops.yaml" ] || die "run inside the repository"
cd "$root"

pub="hosts/$host/ssh.pub"
enc="hosts/$host/ssh.yaml"

# A rerun after an interruption finds its own outputs: the generated config,
# this host's identity and secrets files whose only change is their recipients.
own_change() {
    case "$1" in
    .sops.yaml | "$pub" | "$enc") return 0 ;;
    esac
    git cat-file -e "HEAD:$1" 2>/dev/null || return 1
    [ "$(git show "HEAD:$1" | yq 'del(.sops)')" = "$(yq 'del(.sops)' "$1" 2>/dev/null)" ]
}
while IFS= read -r path; do
    own_change "$path" || die "uncommitted changes to $path; commit or stash them first"
done < <(git status --porcelain -uall -- .sops.yaml hosts secrets infra | cut -c4-)

if [ -f "$pub" ] && [ ! -f "$enc" ] && [ -z "$new_key" ]; then
    die "$pub has no private key in $enc; a new key cuts the live host off its secrets until reinstalled; pass --new-key"
fi

# Before any key or recipient changes: a wrong address or an installed host
# must leave the repo as it was.
if [ "$platform" = nixos ]; then
    ssh_opts=(-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=10 -o BatchMode=yes)
    if ! out=$(ssh "${ssh_opts[@]}" "root@$address" true 2>&1); then
        if grep -q "Permission denied" <<<"$out"; then
            die "root@$address refuses root; $host looks installed (use: just deploy $host), or your SSH key is not loaded"
        fi
        die "cannot reach root@$address: $out"
    fi
fi

# Confirmations and passphrases are typed; a closed stdin would end at `read`.
[ -t 0 ] || die "this needs a terminal; run it interactively"

if [ "$platform" = darwin ] && [ ! -f /etc/ssh/ssh_host_ed25519_key.pub ]; then
    die "this Mac has no SSH host key; turn on Remote Login (or run: sudo ssh-keygen -A) first"
fi

case "$platform" in
nixos) systems=nixosConfigurations ;;
darwin) systems=darwinConfigurations ;;
esac
nix eval --json ".#$systems" --apply builtins.attrNames | jq -e --arg h "$host" 'index($h)' >/dev/null ||
    die "no host $host in $systems"
facts=$(nix eval --json ".#$systems.\"$host\".config" --apply '
  c: {
    image = c ? isoImage;
    keyPath = builtins.head (builtins.filter (p: builtins.match ".*ed25519.*" p != null) (c.sops.age.sshKeyPaths or [ ]) ++ [ "/etc/ssh/ssh_host_ed25519_key" ]);
    device = c.disko.devices.disk.root.device or null;
    luksKeys = map (p: p.content.passwordFile) (builtins.filter (p: (p.content.type or "") == "luks")
      (builtins.attrValues (c.disko.devices.disk.root.content.partitions or { })));
  }')
[ "$(jq -r .image <<<"$facts")" = false ] || die "$host builds an image; write it with just iso-write"
key_path=$(jq -r .keyPath <<<"$facts")

tmp=$(mktemp -d -t bootstrap.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
# Without an exit here, an interrupted prompt would carry on with $tmp gone.
trap 'exit 130' INT TERM
key="$tmp/key"

encrypt() {
    jq -n --rawfile k "$key" '{ ssh_host_ed25519_key: $k }' >"$tmp/key.json"
    sops --encrypt --input-type json --output-type yaml --filename-override "$enc" "$tmp/key.json" >"$tmp/enc"
    ssh-keygen -y -f "$key" >"$tmp/pub"
    mkdir -p "$(dirname "$enc")"
    mv "$tmp/enc" "$enc"
    mv "$tmp/pub" "$pub"
}

# The identity: reuse the repo's, else adopt the Mac's own or make one.
if [ -f "$enc" ] && [ -z "$new_key" ]; then
    (umask 077 && sops --decrypt --extract '["ssh_host_ed25519_key"]' "$enc" >"$key")
    # An interrupted run can leave the private key without its public half.
    [ -f "$pub" ] || ssh-keygen -y -f "$key" >"$pub"
    [ "$(ssh-keygen -y -f "$key" | cut -d' ' -f1-2)" = "$(cut -d' ' -f1-2 "$pub")" ] ||
        die "$enc does not hold the private half of $pub"
    log "Reusing $host's identity from $enc"
elif [ "$platform" = darwin ]; then
    sudo cat /etc/ssh/ssh_host_ed25519_key | (umask 077 && cat >"$key")
    encrypt
    log "Imported this Mac's identity into $enc"
else
    ssh-keygen -q -t ed25519 -N "" -C "root@$host" -f "$key"
    encrypt
    log "Created a new identity for $host in $enc"
fi
git add "$pub" "$enc"

commit_hint() {
    git diff --cached --quiet -- .sops.yaml hosts secrets infra ||
        log "  git commit .sops.yaml hosts secrets infra"
}

# Recipients follow the identity; updatekeys is a no-op where they didn't change.
nix run .#write-sops
for file in secrets/*.yaml hosts/*/ssh.yaml infra/secrets.yaml infra/*/secrets.yaml; do
    [ -f "$file" ] || continue
    sops updatekeys -y "$file" >&2 || die "re-keying $file failed; nothing was installed, rerun when fixed"
    git add "$file"
done
git add .sops.yaml

if [ "$platform" = darwin ]; then
    if [ "$(cut -d' ' -f1-2 "$pub")" != "$(cut -d' ' -f1-2 /etc/ssh/ssh_host_ed25519_key.pub)" ]; then
        confirm "This Mac's SSH host key differs from $host's in the repo; it will be replaced." "$host"
        sudo install -m 600 "$key" /etc/ssh/ssh_host_ed25519_key
        sudo install -m 644 "$pub" /etc/ssh/ssh_host_ed25519_key.pub
        log "Restart sshd to serve it: sudo launchctl kickstart -k system/com.openssh.sshd"
    fi
    log $'\n'"$host has its identity. Next:"
    commit_hint
    log "  nix run .#$host -- switch"
    exit 0
fi

device=$(jq -r .device <<<"$facts")
[ "$device" != null ] || die "$host declares no root disk"
ssh "${ssh_opts[@]}" "root@$address" 'lsblk -o NAME,SIZE,MODEL,TYPE; echo; ls -l /dev/disk/by-id' >&2
ssh "${ssh_opts[@]}" "root@$address" test -e "$device" || die "$device does not exist on $address"
confirm "
Installing $host on $address wipes $device." "$host"

# The tree is copied with its modes onto the target's root.
(umask 022 && mkdir -p "$tmp/extra$(dirname "$key_path")")
install -m 600 "$key" "$tmp/extra$key_path"
install -m 644 "$pub" "$tmp/extra$key_path.pub"

disk_keys=()
n=0
while IFS= read -r -u 3 target; do
    read -r -s -p "Disk passphrase for $host: " pass1 && echo >&2
    read -r -s -p "Again: " pass2 && echo >&2
    [ -n "$pass1" ] && [ "$pass1" = "$pass2" ] || die "passphrases are empty or differ"
    n=$((n + 1))
    printf '%s' "$pass1" >"$tmp/disk$n.key"
    disk_keys+=(--disk-encryption-keys "$target" "$tmp/disk$n.key")
done 3< <(jq -r '.luksKeys | unique[]' <<<"$facts")

nixos-anywhere --flake ".#$host" --extra-files "$tmp/extra" --build-on remote \
    "${disk_keys[@]}" "${extra[@]}" "root@$address"

log $'\n'"$host is installed. Next:"
commit_hint
cat >&2 <<EOF
  just infra-apply dns      # if $host is deployed and publishes names
  just infra-apply router   # if $host has a LAN address
  just deploy $host         # every later change
EOF
