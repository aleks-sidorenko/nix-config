{ routerConfig, ... }:
{
  resource.routeros_interface_ethernet.ether1 = {
    name = "ether1";
    factory_name = "ether1";
    comment = "WAN1";
  };

  resource.routeros_interface_list = {
    WAN = {
      name = "WAN";
      comment = "defconf";
    };
    LAN = {
      name = "LAN";
      comment = "defconf";
    };
  };

  resource.routeros_interface_list_member = {
    bridge_LAN = {
      interface = "bridge";
      list = "LAN";
      comment = "defconf";
    };
    ether1_WAN = {
      interface = "ether1";
      list = "WAN";
      comment = "defconf";
    };
    lte1_WAN = {
      interface = "lte1";
      list = "WAN";
    };
  };

  resource.routeros_interface_lte_apn.default = {
    apn = routerConfig.lte.apn;
    ip_type = "ipv4";
    ipv6_interface = "bridge";
    name = routerConfig.lte.name;
    use_network_apn = false;
  };

  # NOTE: routeros_ovpn_server doesn't work via API mode (api://).
  # The OVPN server config is managed manually on the router.
}
