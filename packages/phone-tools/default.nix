{
  pkgs,
  lib,
  ...
}:
let
  runtimeDeps = with pkgs; [
    ifuse
    libimobiledevice
    android-file-transfer # provides aft-mtp-mount
    rsync
    coreutils
    findutils
    util-linux # mountpoint (NOT in coreutils)
    glib # gio (for gvfs guidance)
    # NOT fuse: fusermount must resolve to /run/wrappers/bin (setuid)
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "phone-tools";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/phone-tools

    # Install shared lib
    cp phone-common.sh $out/lib/phone-tools/

    # Install scripts and wrap with runtime deps
    for script in phone-mount phone-unmount phone-pull phone-clean phone-backup; do
      cp "$script.sh" "$out/bin/$script"
      chmod +x "$out/bin/$script"

      # Patch source path to point to installed location
      substituteInPlace "$out/bin/$script" \
        --replace-fail 'SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' \
        'SCRIPT_DIR="${placeholder "out"}/lib/phone-tools"'

      # $out/bin on PATH so phone-backup can call phone-mount/phone-pull by name
      # regardless of the ambient profile PATH.
      wrapProgram "$out/bin/$script" \
        --prefix PATH : ${placeholder "out"}/bin \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
    done
  '';

  meta = with lib; {
    description = "CLI tools for mounting Android/iPhone and backing up the camera roll";
    platforms = platforms.linux;
  };
}
