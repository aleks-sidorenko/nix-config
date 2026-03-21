_: {
  # Resource IDs discovered from router via `print show-ids`
  # Format: *hex (RouterOS internal IDs)
  import = [

    # ── Bridge ──────────────────────────────────────────────────────
    # /interface bridge print show-ids → *E
    {
      to = "routeros_interface_bridge.bridge";
      id = "*E";
    }

    # /interface bridge port print show-ids → *0..*9
    {
      to = "routeros_interface_bridge_port.ether2";
      id = "*0";
    }
    {
      to = "routeros_interface_bridge_port.ether3";
      id = "*1";
    }
    {
      to = "routeros_interface_bridge_port.ether4";
      id = "*2";
    }
    {
      to = "routeros_interface_bridge_port.ether5";
      id = "*3";
    }
    {
      to = "routeros_interface_bridge_port.ether6";
      id = "*4";
    }
    {
      to = "routeros_interface_bridge_port.ether7";
      id = "*5";
    }
    {
      to = "routeros_interface_bridge_port.ether8";
      id = "*6";
    }
    {
      to = "routeros_interface_bridge_port.ether9";
      id = "*7";
    }
    {
      to = "routeros_interface_bridge_port.ether10";
      id = "*8";
    }
    {
      to = "routeros_interface_bridge_port.sfp1";
      id = "*9";
    }

    # ── Interfaces ──────────────────────────────────────────────────
    # /interface ethernet print show-ids → ether1 = *2
    {
      to = "routeros_interface_ethernet.ether1";
      id = "*2";
    }

    # /interface list print show-ids → WAN=*2000010, LAN=*2000011
    {
      to = "routeros_interface_list.WAN";
      id = "*2000010";
    }
    {
      to = "routeros_interface_list.LAN";
      id = "*2000011";
    }

    # /interface list member print show-ids → *1, *2, *3
    {
      to = "routeros_interface_list_member.bridge_LAN";
      id = "*1";
    }
    {
      to = "routeros_interface_list_member.ether1_WAN";
      id = "*2";
    }
    {
      to = "routeros_interface_list_member.lte1_WAN";
      id = "*3";
    }

    # /interface lte apn print show-ids → *1
    {
      to = "routeros_interface_lte_apn.default";
      id = "*1";
    }

    # routeros_ovpn_server → doesn't work via API mode, managed manually

    # ── CAPsMAN ─────────────────────────────────────────────────────
    # /caps-man channel print show-ids → *1=2G, *2=5G
    {
      to = "routeros_capsman_channel.channel_2G";
      id = "*1";
    }
    {
      to = "routeros_capsman_channel.channel_5G";
      id = "*2";
    }

    # /caps-man datapath print show-ids → *1
    {
      to = "routeros_capsman_datapath.datapath";
      id = "*1";
    }

    # /caps-man security print show-ids → *1
    {
      to = "routeros_capsman_security.security";
      id = "*1";
    }

    # /caps-man configuration print show-ids → *1=2G, *2=5G
    {
      to = "routeros_capsman_configuration.config_2G";
      id = "*1";
    }
    {
      to = "routeros_capsman_configuration.config_5G";
      id = "*2";
    }

    # /caps-man manager → singleton, no ID needed
    {
      to = "routeros_capsman_manager.manager";
      id = "manager";
    }

    # /caps-man manager interface print show-ids → *2=bridge
    {
      to = "routeros_capsman_manager_interface.bridge";
      id = "*2";
    }

    # /caps-man provisioning print show-ids → *1=5G, *2=2G
    {
      to = "routeros_capsman_provisioning.prov_5G";
      id = "*1";
    }
    {
      to = "routeros_capsman_provisioning.prov_2G";
      id = "*2";
    }

    # ── DHCP ────────────────────────────────────────────────────────
    # /ip pool print show-ids → *1
    {
      to = "routeros_ip_pool.dhcp";
      id = "*1";
    }

    # /ip dhcp-server print show-ids → *1
    {
      to = "routeros_ip_dhcp_server.defconf";
      id = "*1";
    }

    # /ip dhcp-server network print show-ids → *1
    {
      to = "routeros_ip_dhcp_server_network.defconf";
      id = "*1";
    }

    # /ip dhcp-client print show-ids → *2=ether1
    {
      to = "routeros_ip_dhcp_client.ether1";
      id = "*2";
    }

    # /ip dhcp-server lease print show-ids (static only)
    # ajax=*1, cap1=*2, cap2=*3, doorbell=*4, heatpump=*5
    # inverter=*6, monitor=*7, server=*8, tv=*9, tv-wifi=*A, 1c-key=*1C
    {
      to = "routeros_ip_dhcp_server_lease.ajax";
      id = "*1";
    }
    {
      to = "routeros_ip_dhcp_server_lease.cap1";
      id = "*2";
    }
    {
      to = "routeros_ip_dhcp_server_lease.cap2";
      id = "*3";
    }
    {
      to = "routeros_ip_dhcp_server_lease.doorbell";
      id = "*4";
    }
    {
      to = "routeros_ip_dhcp_server_lease.heatpump";
      id = "*5";
    }
    {
      to = "routeros_ip_dhcp_server_lease.inverter";
      id = "*6";
    }
    {
      to = "routeros_ip_dhcp_server_lease.monitor";
      id = "*7";
    }
    {
      to = "routeros_ip_dhcp_server_lease.server";
      id = "*8";
    }
    {
      to = "routeros_ip_dhcp_server_lease.tv";
      id = "*9";
    }
    {
      to = "routeros_ip_dhcp_server_lease.tv_wifi";
      id = "*A";
    }
    {
      to = "routeros_ip_dhcp_server_lease._1c_key";
      id = "*1C";
    }

    # ── DNS ─────────────────────────────────────────────────────────
    # /ip dns → doesn't support import, managed via apply only

    # /ip dns static print show-ids
    # *1=FWD *.local, *2=ajax, *3=cap1, *4=cap2, *5=heatpump
    # *6=inverter, *7=monitor, *8=server, *9=tv
    # *A=radarr, *B=jellyfin, *C=qbittorrent, *D=prowlarr
    # *E=minidlna, *F=sonarr, *10=home-assistant, *11=zigbee2mqtt
    # *12=minecraft, *13=restic, *14=1c-key
    {
      to = "routeros_ip_dns_record.local_fwd";
      id = "*1";
    }

    {
      to = "routeros_ip_dns_record.ajax";
      id = "*2";
    }
    {
      to = "routeros_ip_dns_record.cap1";
      id = "*3";
    }
    {
      to = "routeros_ip_dns_record.cap2";
      id = "*4";
    }
    {
      to = "routeros_ip_dns_record.heatpump";
      id = "*5";
    }
    {
      to = "routeros_ip_dns_record.inverter";
      id = "*6";
    }
    {
      to = "routeros_ip_dns_record.monitor";
      id = "*7";
    }
    {
      to = "routeros_ip_dns_record.server";
      id = "*8";
    }
    {
      to = "routeros_ip_dns_record.tv";
      id = "*9";
    }

    {
      to = "routeros_ip_dns_record.alias_radarr";
      id = "*A";
    }
    {
      to = "routeros_ip_dns_record.alias_jellyfin";
      id = "*B";
    }
    {
      to = "routeros_ip_dns_record.alias_qbittorrent";
      id = "*C";
    }
    {
      to = "routeros_ip_dns_record.alias_prowlarr";
      id = "*D";
    }
    {
      to = "routeros_ip_dns_record.alias_minidlna";
      id = "*E";
    }
    {
      to = "routeros_ip_dns_record.alias_sonarr";
      id = "*F";
    }
    {
      to = "routeros_ip_dns_record.alias_home_assistant";
      id = "*10";
    }
    {
      to = "routeros_ip_dns_record.alias_zigbee2mqtt";
      id = "*11";
    }
    {
      to = "routeros_ip_dns_record.alias_minecraft";
      id = "*12";
    }
    {
      to = "routeros_ip_dns_record.alias_restic";
      id = "*13";
    }

    # ── Firewall ────────────────────────────────────────────────────
    # /ip firewall connection tracking → singleton
    {
      to = "routeros_ip_firewall_connection_tracking.default";
      id = "connection_tracking";
    }

    # /ip firewall address-list print show-ids → *1=tv/10.0.0.50, *2=tv/10.0.0.51
    {
      to = "routeros_ip_firewall_addr_list.tv_0";
      id = "*1";
    }
    {
      to = "routeros_ip_firewall_addr_list.tv_1";
      id = "*2";
    }

    # /ip firewall filter print show-ids
    # *F=dummy(dynamic), *1..*E = rules
    {
      to = "routeros_ip_firewall_filter.input_accept_established";
      id = "*1";
    }
    {
      to = "routeros_ip_firewall_filter.input_drop_invalid";
      id = "*2";
    }
    {
      to = "routeros_ip_firewall_filter.input_accept_icmp";
      id = "*3";
    }
    {
      to = "routeros_ip_firewall_filter.input_accept_loopback";
      id = "*4";
    }
    {
      to = "routeros_ip_firewall_filter.input_drop_non_lan";
      id = "*5";
    }
    {
      to = "routeros_ip_firewall_filter.forward_accept_ipsec_in";
      id = "*6";
    }
    {
      to = "routeros_ip_firewall_filter.forward_accept_ipsec_out";
      id = "*7";
    }
    {
      to = "routeros_ip_firewall_filter.forward_fasttrack";
      id = "*8";
    }
    {
      to = "routeros_ip_firewall_filter.forward_accept_established";
      id = "*9";
    }
    {
      to = "routeros_ip_firewall_filter.forward_drop_invalid";
      id = "*A";
    }
    {
      to = "routeros_ip_firewall_filter.forward_drop_wan_not_dstnat";
      id = "*B";
    }
    {
      to = "routeros_ip_firewall_filter.input_drop_dns_tcp";
      id = "*C";
    }
    {
      to = "routeros_ip_firewall_filter.input_drop_dns_udp";
      id = "*D";
    }
    {
      to = "routeros_ip_firewall_filter.forward_drop_tv_external";
      id = "*E";
    }

    # /ip firewall nat print show-ids → *1=masquerade, *2=redirect
    {
      to = "routeros_ip_firewall_nat.masquerade";
      id = "*1";
    }
    {
      to = "routeros_ip_firewall_nat.dns_redirect";
      id = "*2";
    }

    # ── System ──────────────────────────────────────────────────────
    # Singletons
    {
      to = "routeros_system_identity.router";
      id = "identity";
    }
    {
      to = "routeros_system_clock.default";
      id = "clock";
    }

    # /ip address print show-ids → *1=bridge
    {
      to = "routeros_ip_address.bridge";
      id = "*1";
    }

    # /ip service → import fails via API mode, managed via apply

    # Singletons
    # routeros_ip_neighbor_discovery_settings → no .id in API response, managed via apply
    {
      to = "routeros_ip_settings.default";
      id = "ip_settings";
    }
    {
      to = "routeros_ipv6_settings.default";
      id = "ipv6_settings";
    }

    # /ip ipsec profile print show-ids → *A
    {
      to = "routeros_ip_ipsec_profile.default";
      id = "*A";
    }

    # /routing bfd configuration print show-ids → *1
    {
      to = "routeros_routing_bfd_configuration.default";
      id = "*1";
    }

    # Singletons
    {
      to = "routeros_tool_mac_server.default";
      id = "mac_server";
    }
    {
      to = "routeros_tool_mac_server_winbox.default";
      id = "mac_server_winbox";
    }

    # ── Misc ──────────────────────────────────────────────────────
    # NOTE: LCD, serial port, SMB, and wireless security profile settings
    # are not managed via Terraform (no dedicated provider resources).
  ];
}
