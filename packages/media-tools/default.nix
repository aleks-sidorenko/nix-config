{
  pkgs,
  lib,
  ...
}:
let
  runtimeDeps = with pkgs; [
    exiftool
    coreutils
    findutils
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "media-tools";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/media-tools

    # Install shared lib
    cp media-common.sh $out/lib/media-tools/

    # Install scripts and wrap with runtime deps
    for script in media-normalize media-import; do
      cp "$script.sh" "$out/bin/$script"
      chmod +x "$out/bin/$script"

      # Patch source path to point to installed location
      substituteInPlace "$out/bin/$script" \
        --replace-fail 'SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' \
        'SCRIPT_DIR="${placeholder "out"}/lib/media-tools"'

      wrapProgram "$out/bin/$script" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
    done
  '';

  meta = with lib; {
    description = "CLI tools for managing personal media files";
    platforms = platforms.all;
  };
}
