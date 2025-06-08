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

    programs.google-chrome = {
      enable = true;
      package = pkgs.google-chrome;
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/chrome" = [ "${name}.desktop" ];
    };

    home.packages = with pkgs; [
      google-chrome
    ];
  };

}
