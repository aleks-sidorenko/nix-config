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

    programs.chromium = {
      enable = true;
      package = pkgs.chromium;
      commandLineArgs = [
        "--enable-wayland-ime"
        "--ozone-platform=wayland"
        "--enable-logging=stderr"
        "--v=1"
      ];

      extensions = [
        # uBlock Origin
        { id = extensionIds.ublock-origin; }
      ] ++ lib.optionals passCfg.enable [
        { id = extensionIds.browserpass; }
      ];
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/chromium" = [ "${name}.desktop" ];
    };

  };

}
