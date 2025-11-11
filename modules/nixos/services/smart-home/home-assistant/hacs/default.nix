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

  hacs = pkgs.buildHomeAssistantComponent rec {
    owner = "hacs";
    domain = "hacs";
    version = "2.0.5";
    # Use fetchzip instead of fetchFromGitHub because the release includes
    # pre-built frontend assets (hacs_frontend) that aren't in the repository
    src = pkgs.fetchzip {
      url = "https://github.com/hacs/integration/releases/download/${version}/hacs.zip";
      hash = "sha256-iMomioxH7Iydy+bzJDbZxt6BX31UkCvqhXrxYFQV8Gw=";
      stripRoot = false;
    };
    dependencies = with pkgs.home-assistant.python.pkgs; [ aiogithubapi ];

    meta = with lib; {
      description = "HACS gives you a powerful UI to handle downloads of all your custom needs";
      homepage = "https://hacs.xyz/";
      changelog = "https://github.com/hacs/integration/releases/tag/${version}";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
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
