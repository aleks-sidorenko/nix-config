# Deye Inverter Integration via Solarman
#
# This module configures Home Assistant to monitor Deye solar inverters
# using the Solarman custom component.
#
# The Solarman custom component is automatically installed when this module is enabled.
#
# See README.md in this directory for detailed setup instructions.
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
with lib;
with lib.${namespace};
let
  haCfg = config.${namespace}.services.smart-home.home-assistant;
  cfg = haCfg.inverter;

  # Solarman custom component package
  solarman = pkgs.buildHomeAssistantComponent rec {
    owner = "davidrapan";
    domain = "solarman";
    version = "25.08.16";

    src = pkgs.fetchFromGitHub {
      owner = "davidrapan";
      repo = "ha-solarman";
      rev = "v${version}";
      sha256 = "sha256-SsUObH3g3i9xQ4JvRDcCm1Fg2giH+MN3rC3NMPYO5m0=";
      # just github-fetch-hash davidrapan ha-solarman v25.08.16
    };
    dependencies = with pkgs.home-assistant.python.pkgs; [
      aiohttp
      aiofiles
      propcache
      pyyaml
      umodbus
    ];
    meta = with lib; {
      description = "Home Assistant integration for Solarman data loggers";
      homepage = "https://github.com/davidrapan/ha-solarman";
      changelog = "https://github.com/davidrapan/ha-solarman/releases/tag/v${version}";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  };
in
{
  options.${namespace}.services.smart-home.home-assistant.inverter = {
    enable = mkEnableOption "Enable Deye inverter integration via Solarman";

    host = mkOption {
      type = types.str;
      description = "Host name or IP address of the Solarman logger device";
      example = "10.0.0.100";
      default = hosts.local "inverter";
    };

    serialNumber = mkOption {
      type = types.str;
      description = "Serial number of the Solarman logger";
      example = "123456789";
    };

    port = mkOption {
      type = types.port;
      default = 8899;
      description = "Port for Solarman communication";
    };

    inverterModel = mkOption {
      type = types.str;
      default = "deye_p3";
      description = "Inverter model identifier for Solarman";
      example = "deye_p3";
    };

    updateInterval = mkOption {
      type = types.int;
      default = 60;
      description = "Update interval in seconds";
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # No secrets needed for basic Solarman integration
    # If password is required in the future, add SOPS secrets here

    services.home-assistant = {
      # Install Solarman custom component
      customComponents = [
        solarman
      ];

      # Solarman needs these base components
      extraComponents = [
        "sensor"
        "switch"
      ];

      # Add inverter view to dashboard
      lovelaceConfig.views = [
        {
          title = "Solar Inverter";
          path = "inverter";
          icon = "mdi:solar-power";
          catds = [ ];
        }
      ];
    };

    # Ensure custom_components directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d ${haCfg.dataDir}/custom_components 0755 ${haCfg.user} ${haCfg.group} -"
    ];

    # Create Solarman configuration package
    systemd.services.home-assistant.preStart =
      let
        inverterYaml = pkgs.replaceVars ./inverter.yaml {
          inverterHost = cfg.host;
          inverterSerial = cfg.serialNumber;
          inverterPort = toString cfg.port;
          lookupFile = cfg.inverterModel;
          scanInterval = toString cfg.updateInterval;
        };
      in
      ''
        ln -fns ${inverterYaml} ${haCfg.dataDir}/packages/inverter.yaml
      '';
  };
}
