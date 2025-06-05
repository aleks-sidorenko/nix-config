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
let
  cfg = config.${namespace}.browsers.chrome;
  profileName = config.home.username or "default";
in
{
  options.${namespace}.browsers.chrome = {
    enable = mkEnableOption "Enable or disable the Chrome browser.";
  };

  config = mkIf cfg.enable {

    programs.google-chrome = {
      enable = true;
      package = pkgs.google-chrome;
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/chrome" = [ "google-chrome.desktop" ];
    };

    home.packages = with pkgs; [
      google-chrome
    ];
  };

}
