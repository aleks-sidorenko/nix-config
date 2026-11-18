{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "media-tools";
  version = "1.0.0";
  src = ./_media-tools;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/media-tools

    cp media-common.sh $out/lib/media-tools/

    for script in media-normalize media-import media-info; do
      cp "$script.sh" "$out/bin/$script"
      chmod +x "$out/bin/$script"

      # The scripts source their library from beside themselves.
      substituteInPlace "$out/bin/$script" \
        --replace-fail 'SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' \
        'SCRIPT_DIR="${placeholder "out"}/lib/media-tools"'

      wrapProgram "$out/bin/$script" \
        --prefix PATH : ${
          pkgs.lib.makeBinPath (
            builtins.attrValues {
              inherit (pkgs) exiftool coreutils findutils;
            }
          )
        }
    done
  '';

  meta = {
    description = "CLI tools for managing personal media files";
    platforms = pkgs.lib.platforms.all;
  };
}
