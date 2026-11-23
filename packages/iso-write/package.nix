{
  lib,
  stdenv,
  writeShellApplication,
  coreutils,
  gnugrep,
  util-linux,
}:
writeShellApplication {
  name = "iso-write";
  runtimeInputs = [
    coreutils
    gnugrep
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux util-linux;
  text = builtins.readFile ./iso-write.sh;

  # Every refusal must fire before anything touches a disk, so each runs here.
  derivationArgs.postCheck = ''
    refuses() {
      local want="$1"; shift
      if out=$("$target" "$@" 2>&1); then
        echo "expected failure: iso-write $*" >&2; exit 1
      fi
      if ! grep -q -- "$want" <<<"$out"; then
        echo "iso-write $*: expected '$want', got: $out" >&2; exit 1
      fi
    }
    image=$(mktemp)
    refuses Usage
    refuses Usage "$image"
    refuses "not a file" /nonexistent.iso /dev/null
    refuses "not a whole disk" "$image" /dev/null
    refuses "not a whole disk" "$image" /nonexistent
  '';

  meta.description = "Write an image to a whole removable disk, after typing the device back";
}
