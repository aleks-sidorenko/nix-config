{ lib, routerConfig, ... }:
let
  # Firewall filter rules in order (order matters!)
  filterRules = [
    {
      name = "input_accept_established";
      action = "accept";
      chain = "input";
      comment = "defconf: accept established,related,untracked";
      connection_state = "established,related,untracked";
    }
    {
      name = "input_drop_invalid";
      action = "drop";
      chain = "input";
      comment = "defconf: drop invalid";
      connection_state = "invalid";
    }
    {
      name = "input_accept_icmp";
      action = "accept";
      chain = "input";
      comment = "defconf: accept ICMP";
      protocol = "icmp";
    }
    {
      name = "input_accept_loopback";
      action = "accept";
      chain = "input";
      comment = "defconf: accept to local loopback (for CAPsMAN)";
      dst_address = "127.0.0.1";
    }
    {
      name = "input_drop_non_lan";
      action = "drop";
      chain = "input";
      comment = "defconf: drop all not coming from LAN";
      in_interface_list = "!LAN";
    }
    {
      name = "forward_accept_ipsec_in";
      action = "accept";
      chain = "forward";
      comment = "defconf: accept in ipsec policy";
      ipsec_policy = "in,ipsec";
    }
    {
      name = "forward_accept_ipsec_out";
      action = "accept";
      chain = "forward";
      comment = "defconf: accept out ipsec policy";
      ipsec_policy = "out,ipsec";
    }
    {
      name = "forward_fasttrack";
      action = "fasttrack-connection";
      chain = "forward";
      comment = "defconf: fasttrack";
      connection_state = "established,related";
    }
    {
      name = "forward_accept_established";
      action = "accept";
      chain = "forward";
      comment = "defconf: accept established,related, untracked";
      connection_state = "established,related,untracked";
    }
    {
      name = "forward_drop_invalid";
      action = "drop";
      chain = "forward";
      comment = "defconf: drop invalid";
      connection_state = "invalid";
    }
    {
      name = "forward_drop_wan_not_dstnat";
      action = "drop";
      chain = "forward";
      comment = "defconf: drop all from WAN not DSTNATed";
      connection_nat_state = "!dstnat";
      connection_state = "new";
      in_interface_list = "WAN";
    }
    {
      name = "input_drop_dns_tcp";
      action = "drop";
      chain = "input";
      dst_port = 53;
      in_interface_list = "WAN";
      protocol = "tcp";
    }
    {
      name = "input_drop_dns_udp";
      action = "drop";
      chain = "input";
      dst_port = 53;
      in_interface_list = "WAN";
      protocol = "udp";
    }
    {
      name = "forward_drop_tv_external";
      action = "drop";
      chain = "forward";
      comment = "drop TV external traffic";
      out_interface_list = "WAN";
      src_address_list = "tv";
    }
  ];

  # Build rule resources with place_before chaining for ordering
  ruleCount = builtins.length filterRules;

  mkRule =
    idx:
    let
      rule = builtins.elemAt filterRules idx;
      ruleName = rule.name;
      # Remove 'name' from the rule attrs (it's the resource key, not a provider attr)
      ruleAttrs = builtins.removeAttrs rule [ "name" ];
      # Add place_before reference to next rule (except for the last rule)
      withOrdering =
        if idx < ruleCount - 1 then
          let
            nextRule = builtins.elemAt filterRules (idx + 1);
          in
          ruleAttrs
          // {
            place_before = "\${routeros_ip_firewall_filter.${nextRule.name}.id}";
          }
        else
          ruleAttrs;
    in
    {
      name = ruleName;
      value = withOrdering;
    };
in
{
  # Connection tracking
  resource.routeros_ip_firewall_connection_tracking.default = {
    udp_timeout = "10s";
  };

  # Firewall address lists (generated from config)
  resource.routeros_ip_firewall_addr_list = builtins.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        listName: addresses:
        lib.imap0 (
          idx: addr:
          {
            name = "${builtins.replaceStrings [ "-" ] [ "_" ] listName}_${toString idx}";
            value = {
              address = addr;
              list = listName;
            };
          }
        ) addresses
      ) routerConfig.firewallAddressLists
    )
  );

  # Firewall filter rules (ordered via place_before chaining)
  resource.routeros_ip_firewall_filter = builtins.listToAttrs (
    builtins.genList mkRule ruleCount
  );

  # NAT rules
  resource.routeros_ip_firewall_nat = {
    masquerade = {
      action = "masquerade";
      chain = "srcnat";
      comment = "defconf: masquerade";
      ipsec_policy = "out,none";
      out_interface_list = "WAN";
    };
    dns_redirect = {
      action = "redirect";
      chain = "dstnat";
      dst_port = 53;
      protocol = "udp";
      to_addresses = routerConfig.gateway;
      to_ports = 53;
    };
  };
}
