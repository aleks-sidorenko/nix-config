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
  haCfg = config.${namespace}.services.smart-home.home-assistant;
  cfg = haCfg.hacs;

  # Fetch HACS from GitHub
  hacs = pkgs.fetchFromGitHub {
    owner = "hacs";
    repo = "integration";
    rev = "2.0.2";
    sha256 = "sha256-oGzraJquD+ROXRQNc9eYRaWmLjfYJsIEEDn1d1IWhBE=";
  };

in
{
  options.${namespace}.services.smart-home.home-assistant.hacs = {
    enable = mkEnableOption "Enable HACS (Home Assistant Community Store)";
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Add HACS as a custom component
    services.home-assistant = {
      customComponents = [
        hacs
      ];

      # HACS needs these components
      extraComponents = [
        "frontend"
        "websocket_api"
        "http"
      ];
    };

    # Make configuration writable for HACS initial setup
    # After first setup, you can set this back to false if desired
    services.home-assistant.configWritable = mkForce true;

    # Ensure HACS directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d ${haCfg.dataDir}/.storage 0755 ${haCfg.user} ${haCfg.group} -"
      "d ${haCfg.dataDir}/custom_components 0755 ${haCfg.user} ${haCfg.group} -"
    ];

    # Add HACS to the Home Assistant configuration
    services.home-assistant.config = {
      # HACS will auto-register itself as an integration
      # You'll need to add it through the UI after first start
    };
  };
}

