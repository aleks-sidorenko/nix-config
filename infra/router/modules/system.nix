{ routerConfig, ... }:
{
  resource = {
    routeros_system_identity.router = {
      name = "Router";
    };

    routeros_system_clock.default = {
      time_zone_name = routerConfig.timezone;
      time_zone_autodetect = false;
    };

    routeros_ip_address.bridge = {
      address = "${routerConfig.gateway}/${toString routerConfig.prefixLength}";
      interface = "bridge";
      network = routerConfig.networkAddress;
      comment = "defconf";
    };

    # IP services -- enable api for terraform, restrict to LAN
    routeros_ip_service = {
      ftp = {
        numbers = "ftp";
        port = 21;
        disabled = true;
      };
      ssh = {
        numbers = "ssh";
        port = 22;
        address = routerConfig.subnet;
      };
      telnet = {
        numbers = "telnet";
        port = 23;
        disabled = true;
      };
      www = {
        numbers = "www";
        port = 80;
        disabled = true;
      };
      winbox = {
        numbers = "winbox";
        port = 8291;
        address = routerConfig.subnet;
      };
      api = {
        numbers = "api";
        port = 8728;
        disabled = false;
        address = routerConfig.subnet;
      };
      api_ssl = {
        numbers = "api-ssl";
        port = 8729;
        disabled = true;
      };
    };

    routeros_ip_neighbor_discovery_settings.default = {
      discover_interface_list = "LAN";
    };

    routeros_ip_settings.default = {
      max_neighbor_entries = 8192;
    };

    routeros_ipv6_settings.default = {
      accept_router_advertisements = "yes";
      disable_ipv6 = true;
      max_neighbor_entries = 8192;
    };

    routeros_ip_ipsec_profile.default = {
      name = "default";
      dpd_interval = "2m";
      dpd_maximum_failures = 5;
    };

    routeros_routing_bfd_configuration.default = {
      disabled = false;
    };

    routeros_tool_mac_server.default = {
      allowed_interface_list = "LAN";
    };

    routeros_tool_mac_server_winbox.default = {
      allowed_interface_list = "LAN";
    };
  };
}
