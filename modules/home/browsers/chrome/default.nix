{
  inputs,
  lib,
  host,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browsers.chrome;
  name = pkgs.google-chrome.pname;
  profileName = config.home.username or "default";
  passCfg = config.${namespace}.security.pass;

  extensionIds = {
    ublock-origin = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
    browserpass = "naepdomgkenhinolocfifgehidddafch";
    raindrop = "ldgfbffkinooeloadekpmfoklnobpien";
  };
in
{
  options.${namespace}.browsers.chrome = {
    enable = mkEnableOption "Enable or disable the Chrome browser.";
    default = mkBoolOpt false "Whether or not to use Chrome as the default browser.";
  };

  config = mkIf cfg.enable {

    ${namespace}.browsers.default = mkIf cfg.default {
      enable = true;
      name = name;
    };

    programs.browserpass.enable = mkIf passCfg.enable true;

    programs.google-chrome = {
      enable = true;
      package = pkgs.google-chrome;
      commandLineArgs = [
        "--enable-wayland-ime"
        "--ozone-platform=wayland"
        "--enable-logging=stderr"
        "--v=1"
      ];

      # ----------------------------------------------------------------------
      # Chrome doesn't allow exntensions to be installed via command line args,
      # so we have to use the "external extensions" mechanism

      /*
        extensions = [
          # uBlock Origin
          { id = extensionIds.ublock-origin; }
          # Browserpass (conditional on pass being enabled)
        ] ++ lib.optionals passCfg.enable [
          { id = extensionIds.browserpass; }
        ];
      */
      # ----------------------------------------------------------------------
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/chrome" = [ "${name}.desktop" ];
    };

  };

}
