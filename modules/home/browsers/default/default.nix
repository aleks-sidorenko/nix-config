{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browsers.default;

  # List of MIME types for browser associations
  mimeTypes = [
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/xhtml+xml"
    "application/x-extension-xhtml"
    "application/x-extension-xht"
    "application/pdf"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];

in
{
  options.${namespace}.browsers.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default web browser.";
    name = mkStringOpt' "The name of the default browser to use.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "Please specify a browser name in ${namespace}.browsers.default.";
      }
    ];

    ${namespace}.desktops.addons.xdg.associations = mkMimeAssociations cfg.name mimeTypes;
  };

}
