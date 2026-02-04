{ inputs, ... }:
_final: prev: {
  # Overlay for ungoogled-chromium on macOS
  #
  # IMPORTANT:
  # - This downloads the pre-built ungoogled-chromium .dmg for macOS
  # - The sha256 hash must be updated when new versions are released
  # - To get the correct hash for a new version, run:
  #     nix-prefetch-url https://github.com/ungoogled-software/ungoogled-chromium-macos/releases/download/VERSION/ungoogled-chromium_VERSION_macos.dmg
  #   replacing VERSION with the actual version number
  # - Check https://github.com/ungoogled-software/ungoogled-chromium-macos/releases for latest versions
  #
  # This overlay installs the app in $out/programs.
  # The app will be available as ungoogled-chromium package.

  ungoogled-chromium-macos = prev.stdenv.mkDerivation rec {
    pname = "ungoogled-chromium-macos";
    version = "138.0.7204.183-1.1";

    src = prev.fetchurl (
      if prev.stdenv.isAarch64 then
        {
          url = "https://github.com/ungoogled-software/ungoogled-chromium-macos/releases/download/${version}/ungoogled-chromium_${version}_arm64-macos.dmg";
          sha256 = "sha256-vTdhq+NmlzXVqC6wqE1Es+XolZfIlcoeS6gPzwhajRI=";
        }
      else
        {
          url = "https://github.com/ungoogled-software/ungoogled-chromium-macos/releases/download/${version}/ungoogled-chromium_${version}_x86_64-macos.dmg";
          sha256 = "sha256-waLhUYViKQ3SfQnunc4JI8E4iBH+WWOVjJYCSikr9tA=";
        }
    );

    nativeBuildInputs = [ prev.undmg ];

    sourceRoot = "Chromium.app";

    installPhase = ''
      mkdir -p $out/Applications
      cp -r . $out/Applications/Chromium.app

      # Create a symlink in bin for command line access
      mkdir -p $out/bin
      ln -s $out/Applications/Chromium.app/Contents/MacOS/Chromium $out/bin/chromium
    '';

    meta = with prev.lib; {
      description = "ungoogled-chromium for macOS - A lightweight approach to removing Google web service dependency";
      longDescription = ''
        ungoogled-chromium is Google Chromium, sans integration with Google.
        It also features some tweaks to enhance privacy, control, and transparency.
        This is a community-maintained build for macOS.
      '';
      homepage = "https://github.com/ungoogled-software/ungoogled-chromium-macos";
      license = licenses.bsd3;
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      maintainers = [ ];
    };
  };
}
