{ routerConfig, ... }:
{
  resource.routeros_interface_ethernet.ether1 = {
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

  resource.routeros_interface_ovpn_server.ovpn_server1 = {
    enabled = true;
    auth = "sha1,md5";
    mac_address = routerConfig.ovpn.macAddress;
  };
}
