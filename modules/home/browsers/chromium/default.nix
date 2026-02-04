{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browsers.chromium;
  name = pkgs.chromium.pname;
  passCfg = config.${namespace}.security.pass;

  extensionIds = {
    ublock-origin = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
    browserpass = "naepdomgkenhinolocfifgehidddafch";
  };
in
{
  options.${namespace}.browsers.chromium = {
    enable = mkEnableOption "Enable or disable the Chromium browser.";
    default = mkBoolOpt false "Whether or not to use Chromium as the default browser.";
  };

  config = mkIf cfg.enable {

    ${namespace}.browsers.default = mkIf cfg.default {
      enable = true;
      name = name;
    };

    programs.browserpass.enable = mkIf passCfg.enable true;

    # On Darwin (macOS), install the pre-built app directly
    home.packages = mkIf (pkgs.stdenv.isDarwin) [
      pkgs.ungoogled-chromium-macos
    ];

    # On NixOS (Linux), configure via program
    programs.chromium = mkIf (pkgs.stdenv.isLinux) {
      enable = true;
      package = pkgs.ungoogled-chromium;
      commandLineArgs = [
        # Performance
        "--gtk-version=4"
        "--ignore-gpu-blocklist"
        "--enable-gpu-rasterization"
        "--enable-oop-rasterization"
        "--enable-zero-copy"
        "--ignore-gpu-blocklist"
        # Etc
        "--disk-cache=$XDG_RUNTIME_DIR/chromium-cache"
        "--disable-reading-from-canvas"
        "--no-first-run"
        "--disable-wake-on-wifi"
        "--disable-speech-api"
        "--disable-speech-synthesis-api"
        # Use strict extension verification
        "--extension-content-verification=enforce_strict"
        "--extensions-install-verification=enforce_strict"
        # Disable pings
        "--no-pings"
        # Require HTTPS for component updater
        "--component-updater=require_encryption"
        # Disable crash upload
        "--no-crash-upload"
        # don't run things without asking
        "--no-service-autorun"
        # Disable sync
        "--disable-sync"
        # Disable autofill
        "AutofillPaymentCardBenefits"
        "AutofillPaymentCvcStorage"
        "AutofillPaymentCardBenefits"
      ];

      extensions = [
        # uBlock Origin
        { id = extensionIds.ublock-origin; }
      ]
      ++ lib.optionals passCfg.enable [
        { id = extensionIds.browserpass; }
      ];
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/chromium" = [ "${name}.desktop" ];
    };

  };

}
