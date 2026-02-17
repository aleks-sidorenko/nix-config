cfg: {
  # CAPsMAN Channel Configuration
  "/caps-man channel" = [
    {
      name = "2G";
      band = "2ghz-b/g/n";
      control-channel-width = "20mhz";
    }
    {
      name = "5G";
      band = "5ghz-a/n/ac";
      control-channel-width = "20mhz";
    }
  ];

  # Bridge
  "/interface bridge" = [
    {
      name = "bridge";
      admin-mac = cfg.bridge.adminMac;
      auto-mac = false;
      comment = "defconf";
      port-cost-mode = "short";
    }
  ];

  # Ethernet interfaces
  "/interface ethernet" = {
    "[ find default-name=ether1 ]" = {
      comment = "WAN1";
    };
  };

  # CAPsMAN Datapath
  "/caps-man datapath" = [
    {
      name = "datapath";
      bridge = "bridge";
      client-to-client-forwarding = true;
      local-forwarding = true;
    }
  ];

  # CAPsMAN Security (WiFi password injected at runtime)
  "/caps-man security" = [
    {
      name = "security";
      authentication-types = [
        "wpa-psk"
        "wpa2-psk"
      ];
      encryption = [ "aes-ccm" ];
      passphrase = "$WIFI_PASSWORD";
    }
  ];

  # CAPsMAN Configuration
  "/caps-man configuration" = [
    {
      name = "2G";
      channel = "2G";
      country = "ukraine";
      datapath = "datapath";
      installation = "any";
      mode = "ap";
      rx-chains = [
        "0"
        "1"
        "2"
        "3"
      ];
      security = "security";
      ssid = cfg.wifi.ssid;
      tx-chains = [
        "0"
        "1"
        "2"
        "3"
      ];
    }
    {
      name = "5G";
      channel = "5G";
      country = "ukraine";
      datapath = "datapath";
      installation = "any";
      mode = "ap";
      rx-chains = [
        "0"
        "1"
        "2"
        "3"
      ];
      security = "security";
      ssid = cfg.wifi.ssid;
      tx-chains = [
        "0"
        "1"
        "2"
        "3"
      ];
    }
  ];

  # Interface Lists
  "/interface list" = [
    {
      name = "WAN";
      comment = "defconf";
    }
    {
      name = "LAN";
      comment = "defconf";
    }
  ];

  # LTE APN
  "/interface lte apn" = {
    "[ find default=yes ]" = {
      apn = cfg.lte.apn;
      ip-type = "ipv4";
      ipv6-interface = "bridge";
      name = cfg.lte.name;
      use-network-apn = false;
    };
  };

  # Wireless security profiles
  "/interface wireless security-profiles" = {
    "[ find default=yes ]" = {
      supplicant-identity = "MikroTik";
    };
  };

  # IP Pool
  "/ip pool" = [
    {
      name = "dhcp";
      ranges = cfg.dhcpRange;
    }
  ];

  # DHCP Server
  "/ip dhcp-server" = [
    {
      name = "defconf";
      address-pool = "dhcp";
      interface = "bridge";
      lease-time = "1d";
    }
  ];

  # SMB Users
  "/ip smb users" = {
    "[ find default=yes ]" = {
      disabled = true;
    };
  };

  # Port
  "/port" = {
    "0" = {
      name = "serial0";
    };
  };

  # CAPsMAN Manager
  "/caps-man manager" = {
    no_label = {
      enabled = true;
      upgrade-policy = "require-same-version";
    };
  };

  "/caps-man manager interface" = [
    {
      disabled = false;
      interface = "bridge";
    }
  ];

  # CAPsMAN Provisioning
  "/caps-man provisioning" = [
    {
      action = "create-dynamic-enabled";
      hw-supported-modes = "ac";
      master-configuration = "5G";
      name-format = "prefix-identity";
      name-prefix = "5G";
    }
    {
      action = "create-dynamic-enabled";
      hw-supported-modes = "gn";
      master-configuration = "2G";
      name-format = "prefix-identity";
      name-prefix = "2G";
    }
  ];

  # Bridge Ports
  "/interface bridge port" =
    map
      (iface: {
        bridge = "bridge";
        interface = iface;
        comment = "defconf";
        ingress-filtering = false;
        internal-path-cost = 10;
        path-cost = 10;
      })
      [
        "ether2"
        "ether3"
        "ether4"
        "ether5"
        "ether6"
        "ether7"
        "ether8"
        "ether9"
        "ether10"
        "sfp1"
      ];

  # Firewall connection tracking
  "/ip firewall connection tracking" = {
    no_label = {
      udp-timeout = "10s";
    };
  };

  # Neighbor discovery
  "/ip neighbor discovery-settings" = {
    no_label = {
      discover-interface-list = "LAN";
    };
  };

  # IP Settings
  "/ip settings" = {
    no_label = {
      max-neighbor-entries = 8192;
    };
  };

  # IPv6 Settings
  "/ipv6 settings" = {
    no_label = {
      accept-router-advertisements = true;
      disable-ipv6 = true;
      max-neighbor-entries = 8192;
      soft-max-neighbor-entries = 8191;
    };
  };

  # Interface List Members
  "/interface list member" = [
    {
      interface = "bridge";
      list = "LAN";
      comment = "defconf";
    }
    {
      interface = "ether1";
      list = "WAN";
      comment = "defconf";
    }
    {
      interface = "lte1";
      list = "WAN";
    }
  ];

  # OpenVPN Server
  "/interface ovpn-server server" = [
    {
      name = "ovpn-server1";
      auth = [
        "sha1"
        "md5"
      ];
      mac-address = cfg.ovpn.macAddress;
    }
  ];

  # IP Address
  "/ip address" = [
    {
      address = "${cfg.gateway}/${toString cfg.prefixLength}";
      interface = "bridge";
      network = cfg.networkAddress;
      comment = "defconf";
    }
  ];

  # DHCP Client
  "/ip dhcp-client" = [
    {
      interface = "ether1";
      comment = "defconf";
    }
  ];

  # DHCP Server Leases (generated from hosts)
  "/ip dhcp-server lease" = cfg.dhcpLeases;

  # DHCP Server Network
  "/ip dhcp-server network" = [
    {
      address = cfg.subnet;
      gateway = cfg.gateway;
      dns-server = cfg.gateway;
      netmask = cfg.prefixLength;
      comment = "defconf";
    }
  ];

  # DNS Settings
  "/ip dns" = {
    no_label = {
      allow-remote-requests = true;
      servers = cfg.dns.upstream;
    };
  };

  # DNS Static (FWD rule + records from hosts)
  "/ip dns static" = [
    {
      forward-to = cfg.gateway;
      regexp = "\".*\\\\.${cfg.localDomain}\\$\"";
      type = "FWD";
    }
  ]
  ++ cfg.dnsStaticRecords;

  # Firewall Address Lists (generated from firewallAddressLists option)
  "/ip firewall address-list" = builtins.concatLists (
    builtins.attrValues (
      builtins.mapAttrs (
        listName: addresses:
        map (addr: {
          address = addr;
          list = listName;
        }) addresses
      ) cfg.firewallAddressLists
    )
  );

  # Firewall Filter Rules
  "/ip firewall filter" = [
    {
      action = "accept";
      chain = "input";
      comment = "defconf: accept established,related,untracked";
      connection-state = [
        "established"
        "related"
        "untracked"
      ];
    }
    {
      action = "drop";
      chain = "input";
      comment = "defconf: drop invalid";
      connection-state = [ "invalid" ];
    }
    {
      action = "accept";
      chain = "input";
      comment = "defconf: accept ICMP";
      protocol = "icmp";
    }
    {
      action = "accept";
      chain = "input";
      comment = "defconf: accept to local loopback (for CAPsMAN)";
      dst-address = "127.0.0.1";
    }
    {
      action = "drop";
      chain = "input";
      comment = "defconf: drop all not coming from LAN";
      in-interface-list = "!LAN";
    }
    {
      action = "accept";
      chain = "forward";
      comment = "defconf: accept in ipsec policy";
      ipsec-policy = "in,ipsec";
    }
    {
      action = "accept";
      chain = "forward";
      comment = "defconf: accept out ipsec policy";
      ipsec-policy = "out,ipsec";
    }
    {
      action = "fasttrack-connection";
      chain = "forward";
      comment = "defconf: fasttrack";
      connection-state = [
        "established"
        "related"
      ];
    }
    {
      action = "accept";
      chain = "forward";
      comment = "defconf: accept established,related, untracked";
      connection-state = [
        "established"
        "related"
        "untracked"
      ];
    }
    {
      action = "drop";
      chain = "forward";
      comment = "defconf: drop invalid";
      connection-state = [ "invalid" ];
    }
    {
      action = "drop";
      chain = "forward";
      comment = "defconf: drop all from WAN not DSTNATed";
      connection-nat-state = "!dstnat";
      connection-state = [ "new" ];
      in-interface-list = "WAN";
    }
    {
      action = "drop";
      chain = "input";
      dst-port = 53;
      in-interface-list = "WAN";
      protocol = "tcp";
    }
    {
      action = "drop";
      chain = "input";
      dst-port = 53;
      in-interface-list = "WAN";
      protocol = "udp";
    }
    {
      action = "drop";
      chain = "forward";
      comment = "drop TV external traffic";
      out-interface-list = "WAN";
      src-address-list = "tv";
    }
  ];

  # Firewall NAT
  "/ip firewall nat" = [
    {
      action = "masquerade";
      chain = "srcnat";
      comment = "defconf: masquerade";
      ipsec-policy = "out,none";
      out-interface-list = "WAN";
    }
    {
      action = "redirect";
      chain = "dstnat";
      dst-port = 53;
      protocol = "udp";
      to-addresses = cfg.gateway;
      to-ports = 53;
    }
  ];

  # IPsec Profile
  "/ip ipsec profile" = {
    "[ find default=yes ]" = {
      dpd-interval = "2m";
      dpd-maximum-failures = 5;
    };
  };

  # IP Services
  "/ip service" = {
    ftp = {
      disabled = true;
    };
    ssh = {
      address = cfg.subnet;
    };
    telnet = {
      disabled = true;
    };
    www = {
      disabled = true;
    };
    winbox = {
      address = cfg.subnet;
    };
    api = {
      disabled = true;
    };
    api-ssl = {
      disabled = true;
    };
  };

  # SMB Shares
  "/ip smb shares" = {
    "[ find default=yes ]" = {
      directory = "/pub";
    };
  };

  # LCD
  "/lcd" = {
    no_label = {
      default-screen = "log";
      enabled = false;
      touch-screen = "disabled";
    };
  };

  # Routing BFD
  "/routing bfd configuration" = [
    { disabled = false; }
  ];

  # System Clock
  "/system clock" = {
    no_label = {
      time-zone-name = cfg.timezone;
    };
  };

  # System Identity
  "/system identity" = {
    no_label = {
      name = "Router";
    };
  };

  # Tool MAC Server
  "/tool mac-server" = {
    no_label = {
      allowed-interface-list = "LAN";
    };
  };

  "/tool mac-server mac-winbox" = {
    no_label = {
      allowed-interface-list = "LAN";
    };
  };
}
