{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.xcode;
  developerDir = "${cfg.path}/Contents/Developer";
  # Pin the toolchain per call: the activation environment may carry a
  # DEVELOPER_DIR from nixpkgs' apple-sdk, which hides Xcode.
  xcodebuild = "DEVELOPER_DIR=${developerDir} /usr/bin/xcodebuild";
  xcrun = "DEVELOPER_DIR=${developerDir} /usr/bin/xcrun";
in
{
  options.${namespace}.system.xcode = with types; {
    enable = mkBoolOpt false "Whether to finish Xcode setup (select, licence, first launch, simulators) on activation";
    path = mkStringOpt "/Applications/Xcode.app" "Path to the Xcode app bundle (installed separately, e.g. via masApps)";
    acceptLicense = mkBoolOpt false "Accept the Xcode licence agreement non-interactively (opt-in: this agrees to Apple's terms)";
    simulatorPlatforms = mkOpt (listOf (enum [
      "iOS"
      "watchOS"
      "tvOS"
      "visionOS"
    ])) [ ] "Simulator runtimes to download when none for that platform is installed";
  };

  config = mkIf cfg.enable {
    # Xcode itself arrives through Homebrew/mas earlier in activation; every
    # step below checks before acting, so later switches are no-ops. Nothing
    # runs until the app bundle exists (e.g. before the App Store sign-in).
    system.activationScripts.postActivation.text = ''
      if [ -d ${cfg.path} ]; then
        # -p honours DEVELOPER_DIR; read the system-wide selection instead.
        if [ "$(env -u DEVELOPER_DIR /usr/bin/xcode-select -p 2>/dev/null)" != "${developerDir}" ]; then
          printf >&2 'selecting %s...\n' ${developerDir}
          /usr/bin/xcode-select -s ${developerDir}
        fi
      ${optionalString cfg.acceptLicense ''
        # Re-checked every switch: an Xcode update brings a new licence.
        if ! ${xcodebuild} -license check >/dev/null 2>&1; then
          printf >&2 'accepting the Xcode licence...\n'
          ${xcodebuild} -license accept
        fi
      ''}
        # Installs CoreSimulator and other system components; without it simctl
        # cannot run. Also re-needed after Xcode updates.
        if ! ${xcodebuild} -checkFirstLaunchStatus >/dev/null 2>&1; then
          printf >&2 'running Xcode first-launch setup...\n'
          ${xcodebuild} -runFirstLaunch
        fi
      ${concatMapStrings (platform: ''
        if ! ${xcrun} simctl list runtimes 2>/dev/null | grep -q '^${platform} '; then
          printf >&2 'downloading the ${platform} simulator runtime (several GB)...\n'
          # Network-bound: an offline switch must not abort the rest of
          # activation (set -e), so warn and retry on the next switch.
          ${xcodebuild} -downloadPlatform ${platform} \
            || printf >&2 'warning: ${platform} simulator download failed; will retry on next switch\n'
        fi
      '') cfg.simulatorPlatforms}
      fi
    '';
  };
}
