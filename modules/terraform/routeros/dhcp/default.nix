{ lib, routerConfig, ... }:
{
  resource.routeros_ip_pool.dhcp = {
    name = "dhcp";
    ranges = [ routerConfig.dhcpRange ];
  };

  resource.routeros_ip_dhcp_server.defconf = {
    name = "defconf";
    address_pool = "dhcp";
    interface = "bridge";
    lease_time = "1d";
    dynamic_lease_identifiers = "client-mac,client-id";
  };

  resource.routeros_ip_dhcp_server_network.defconf = {
    address = routerConfig.subnet;
    gateway = routerConfig.gateway;
    dns_server = [ routerConfig.gateway ];
    netmask = toString routerConfig.prefixLength;
    comment = "defconf";
  };

  resource.routeros_ip_dhcp_client.ether1 = {
    interface = "ether1";
    comment = "defconf";
  };

  # DHCP leases generated from hosts
  resource.routeros_ip_dhcp_server_lease = builtins.listToAttrs (
    lib.mapAttrsToList (name: host: {
      name =
        let
          sanitized = builtins.replaceStrings [ "-" ] [ "_" ] name;
        in
        if builtins.match "[0-9].*" sanitized != null then "_${sanitized}" else sanitized;
      value = {
        address = host.ip;
        mac_address = lib.toUpper host.mac;
        comment = if host.comment != "" then host.comment else name;
        server = "defconf";
      };
    }) (lib.filterAttrs (_: host: host.dhcp or true) routerConfig.hosts)
  );
}
