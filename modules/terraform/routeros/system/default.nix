{ routerConfig, ... }:
{
  resource.routeros_system_identity.router = {
    name = "Router";
  };

  resource.routeros_system_clock.default = {
    time_zone_name = routerConfig.timezone;
    time_zone_autodetect = false;
  };

  resource.routeros_ip_address.bridge = {
    address = "${routerConfig.gateway}/${toString routerConfig.prefixLength}";
    interface = "bridge";
    network = routerConfig.networkAddress;
    comment = "defconf";
  };

  # IP services -- enable api for terraform, restrict to LAN
  resource.routeros_ip_service = {
    ftp = {
      numbers = "ftp";
      disabled = true;
    };
    ssh = {
      numbers = "ssh";
      address = routerConfig.subnet;
    };
    telnet = {
      numbers = "telnet";
      disabled = true;
    };
    www = {
      numbers = "www";
      disabled = true;
    };
    winbox = {
      numbers = "winbox";
      address = routerConfig.subnet;
    };
    api = {
      numbers = "api";
      disabled = false;
      address = routerConfig.subnet;
    };
    api_ssl = {
      numbers = "api-ssl";
      disabled = true;
    };
  };

  resource.routeros_ip_neighbor_discovery_settings.default = {
    discover_interface_list = "LAN";
  };

  resource.routeros_ip_settings.default = {
    max_neighbor_entries = 8192;
  };

  resource.routeros_ipv6_settings.default = {
    accept_router_advertisements = true;
    disable_ipv6 = true;
    max_neighbor_entries = 8192;
  };

  resource.routeros_ip_ipsec_profile.default = {
    name = "default";
    dpd_interval = "2m";
    dpd_maximum_failures = 5;
  };

  resource.routeros_routing_bfd_configuration.default = {
    disabled = false;
  };

  resource.routeros_tool_mac_server.default = {
    allowed_interface_list = "LAN";
  };

  resource.routeros_tool_mac_server_winbox.default = {
    allowed_interface_list = "LAN";
  };
}
