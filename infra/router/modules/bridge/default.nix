{ routerConfig, ... }:
let
  bridgePorts = [
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
in
{
  resource.routeros_interface_bridge.bridge = {
    name = "bridge";
    admin_mac = routerConfig.bridge.adminMac;
    auto_mac = false;
    comment = "defconf";
    port_cost_mode = "short";
  };

  resource.routeros_interface_bridge_port = builtins.listToAttrs (
    builtins.map (iface: {
      name = iface;
      value = {
        bridge = "bridge";
        interface = iface;
        comment = "defconf";
        ingress_filtering = false;
        internal_path_cost = 10;
        path_cost = 10;
      };
    }) bridgePorts
  );
}
