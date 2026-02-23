{ routerConfig, ... }:
{
  resource.routeros_capsman_channel = {
    "channel_2G" = {
      name = "2G";
      band = "2ghz-b/g/n";
      control_channel_width = "20mhz";
    };
    "channel_5G" = {
      name = "5G";
      band = "5ghz-a/n/ac";
      control_channel_width = "20mhz";
    };
  };

  resource.routeros_capsman_datapath.datapath = {
    name = "datapath";
    bridge = "bridge";
    client_to_client_forwarding = true;
    local_forwarding = true;
  };

  resource.routeros_capsman_security.security = {
    name = "security";
    authentication_types = [
      "wpa-psk"
      "wpa2-psk"
    ];
    encryption = [ "aes-ccm" ];
    passphrase = "\${var.wifi_password}";
  };

  resource.routeros_capsman_configuration = {
    config_2G = {
      name = "2G";
      channel = "2G";
      country = "ukraine";
      datapath = "datapath";
      installation = "any";
      mode = "ap";
      rx_chains = [
        0
        1
        2
        3
      ];
      security = "security";
      ssid = routerConfig.wifi.ssid;
      tx_chains = [
        0
        1
        2
        3
      ];
    };
    config_5G = {
      name = "5G";
      channel = "5G";
      country = "ukraine";
      datapath = "datapath";
      installation = "any";
      mode = "ap";
      rx_chains = [
        0
        1
        2
        3
      ];
      security = "security";
      ssid = routerConfig.wifi.ssid;
      tx_chains = [
        0
        1
        2
        3
      ];
    };
  };

  resource.routeros_capsman_manager.manager = {
    enabled = true;
    upgrade_policy = "require-same-version";
  };

  resource.routeros_capsman_manager_interface.bridge = {
    disabled = false;
    interface = "bridge";
  };

  resource.routeros_capsman_provisioning = {
    prov_5G = {
      action = "create-dynamic-enabled";
      hw_supported_modes = "ac";
      master_configuration = "5G";
      name_format = "prefix-identity";
      name_prefix = "5G";
    };
    prov_2G = {
      action = "create-dynamic-enabled";
      hw_supported_modes = "gn";
      master_configuration = "2G";
      name_format = "prefix-identity";
      name_prefix = "2G";
    };
  };
}
