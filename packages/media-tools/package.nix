{
  lib,
  stdenvNoCC,
  makeWrapper,
  exiftool,
  coreutils,
  findutils,
  shell-lib,
}:
let
  runtimeInputs = [
    exiftool
    coreutils
    findutils
  ];
in
stdenvNoCC.mkDerivation {
  pname = "media-tools";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  # In a checkout it sources the helpers by their path in the repo.
  postPatch = ''
    substituteInPlace media-common.sh \
      --replace-fail '$(dirname "''${BASH_SOURCE[0]}")/../shell-lib/shell-lib.sh' ${shell-lib}
  '';

  doCheck = true;
  nativeCheckInputs = runtimeInputs;
  checkPhase = ''
    runHook preCheck
    bash test/run-tests.sh
    runHook postCheck
  '';

  # Run as installed, through the wrapper, messages still name the tool.
  doInstallCheck = true;
  installCheckPhase = ''
    out=$($out/bin/media-import /nonexistent /tmp 2>&1) && exit 1
    grep -q '^media-import: Source directory does not exist' <<<"$out" || { echo "got: $out" >&2; exit 1; }
  '';

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

      wrapProgram "$out/bin/$script" --prefix PATH : ${lib.makeBinPath runtimeInputs}
    done
  '';

  meta = {
    description = "CLI tools for managing personal media files";
    platforms = lib.platforms.all;
  };
}
