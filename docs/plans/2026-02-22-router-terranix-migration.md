# MikroTik Router Terranix Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the custom `.rsc` script generator with a terranix/OpenTofu approach using `packages/router/` and `modules/terraform/routeros/`.

**Architecture:** Terranix modules define RouterOS resources in Nix. A `mkTerranixDerivation` library function wraps OpenTofu commands as passthru scripts on a nix package. The `packages/router/` package assembles config data from `lib/defaults` and passes it to terranix modules via `extraArgs`.

**Tech Stack:** terranix, OpenTofu (`pkgs.opentofu`), terraform-routeros/routeros provider (old API), snowfall-lib, SOPS for secrets, OpenTofu native state encryption (PBKDF2 + AES-GCM)

---

## Task 1: Add terranix flake input

**Files:**
- Modify: `flake.nix:96-101` (after `deploy-rs` input)

**Step 1: Add terranix input**

In `flake.nix`, add after the `deploy-rs` input block (line 101):

```nix
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

**Step 2: Verify flake lock updates**

Run: `nix flake lock --update-input terranix`
Expected: flake.lock updated with terranix hash

**Step 3: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat(router): add terranix flake input"
```

---

## Task 2: Create `lib/terraform/default.nix`

**Files:**
- Create: `lib/terraform/default.nix`

**Step 1: Create the library module**

OpenTofu handles state encryption natively via the `terraform.encryption` block in the terranix config. The scripts just need to copy `config.tf.json` into `stateDir` and run `tofu` there.

```nix
{
  lib,
  inputs,
  ...
}:
rec {
  # Recursively find all default.nix files in a directory tree
  findDefaultNixFiles =
    path:
    let
      scanDir =
        dir:
        let
          entries = builtins.readDir dir;
          files = builtins.filter (
            name: entries.${name} == "regular" && name == "default.nix"
          ) (builtins.attrNames entries);
          filePaths = builtins.map (file: "${dir}/${file}") files;
          subDirs = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
          subDirPaths = builtins.concatLists (builtins.map (subDir: scanDir "${dir}/${subDir}") subDirs);
        in
        filePaths ++ subDirPaths;
    in
    scanDir path;

  # Create a terranix derivation with passthru scripts for plan/apply/destroy
  # Uses OpenTofu for native state encryption (configured in terranix modules)
  mkTerranixDerivation =
    {
      pkgs,
      system,
      extraArgs ? { },
      modules,
      terraformModulesPath ? null,
      stateDir ? ".",
      envVars ? [
        "TF_VAR_routeros_password"
        "TF_VAR_wifi_password"
        "TF_VAR_state_passphrase"
      ],
    }:
    let
      globalModules =
        if terraformModulesPath != null then findDefaultNixFiles terraformModulesPath else [ ];

      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        extraArgs = {
          inherit lib pkgs;
        } // extraArgs;
        modules = globalModules ++ modules;
      };

      tofu = "${pkgs.opentofu}/bin/tofu";

      envCheck = lib.concatMapStringsSep "\n" (
        var: ''
          if [[ -z "''${${var}:-}" ]]; then
            echo "Error: ${var} not set"
            exit 1
          fi
        ''
      ) envVars;

      tfSetup = ''
        cd "${stateDir}"
        cp -f ${terraformConfiguration} config.tf.json
      '';

      show = pkgs.writeShellScriptBin "show" ''
        set -euo pipefail
        cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
      '';

      plan = pkgs.writeShellScriptBin "plan" ''
        set -euo pipefail
        ${envCheck}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} plan
      '';

      apply = pkgs.writeShellScriptBin "apply" ''
        set -euo pipefail
        ${envCheck}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} apply
      '';

      destroy = pkgs.writeShellScriptBin "destroy" ''
        set -euo pipefail
        ${envCheck}
        ${tfSetup}
        ${tofu} init -input=false
        ${tofu} destroy
      '';
    in
    show
    // {
      inherit
        plan
        apply
        destroy
        ;
    };
}
```

**Step 2: Verify nix evaluation**

Run: `nix eval .#lib --apply 'lib: builtins.hasAttr "mkTerranixDerivation" lib.nix-config'`
Expected: `true`

**Step 3: Commit**

```bash
git add lib/terraform/default.nix
git commit -m "feat(router): add mkTerranixDerivation library"
```

---

## Task 3: Create terranix provider module

**Files:**
- Create: `modules/terraform/routeros/provider/default.nix`

**Step 1: Create provider configuration**

Includes OpenTofu native state encryption via PBKDF2 + AES-GCM. The passphrase is passed via `TF_VAR_state_passphrase` from SOPS.

```nix
{ routerConfig, ... }:
{
  terraform = {
    required_providers.routeros = {
      source = "terraform-routeros/routeros";
      version = "~> 1.99";
    };

    # OpenTofu native state encryption
    encryption = {
      key_provider.pbkdf2.state = {
        passphrase = "\${var.state_passphrase}";
      };
      method.aes_gcm.state = {
        keys = "\${key_provider.pbkdf2.state}";
      };
      state = {
        method = "\${method.aes_gcm.state}";
      };
      # Uncomment for initial migration from unencrypted state:
      # method.unencrypted.migration = {};
      # state.fallback.method = "\${method.unencrypted.migration}";
    };
  };

  provider.routeros = {
    hosturl = "api://${routerConfig.gateway}";
    username = "\${var.routeros_username}";
    password = "\${var.routeros_password}";
  };

  variable = {
    routeros_username = {
      type = "string";
      default = "admin";
      description = "RouterOS API username";
    };
    routeros_password = {
      type = "string";
      sensitive = true;
      description = "RouterOS API password";
    };
    wifi_password = {
      type = "string";
      sensitive = true;
      description = "WiFi password for CAPsMAN security";
    };
    state_passphrase = {
      type = "string";
      sensitive = true;
      description = "Passphrase for OpenTofu state encryption (min 16 chars)";
    };
  };
}
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/provider/default.nix
git commit -m "feat(router): add terranix provider module"
```

---

## Task 4: Create terranix bridge module

**Files:**
- Create: `modules/terraform/routeros/bridge/default.nix`

**Step 1: Create bridge and port resources**

```nix
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
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/bridge/default.nix
git commit -m "feat(router): add terranix bridge module"
```

---

## Task 5: Create terranix interfaces module

**Files:**
- Create: `modules/terraform/routeros/interfaces/default.nix`

**Step 1: Create interface resources**

```nix
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
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/interfaces/default.nix
git commit -m "feat(router): add terranix interfaces module"
```

---

## Task 6: Create terranix CAPsMAN module

**Files:**
- Create: `modules/terraform/routeros/capsman/default.nix`

**Step 1: Create CAPsMAN resources**

```nix
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
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/capsman/default.nix
git commit -m "feat(router): add terranix CAPsMAN module"
```

---

## Task 7: Create terranix DHCP module

**Files:**
- Create: `modules/terraform/routeros/dhcp/default.nix`

**Step 1: Create DHCP resources**

```nix
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
  };

  resource.routeros_ip_dhcp_server_network.defconf = {
    address = routerConfig.subnet;
    gateway = routerConfig.gateway;
    dns_server = routerConfig.gateway;
    netmask = toString routerConfig.prefixLength;
    comment = "defconf";
  };

  resource.routeros_ip_dhcp_client.ether1 = {
    interface = "ether1";
    comment = "defconf";
  };

  # DHCP leases generated from hosts
  resource.routeros_ip_dhcp_server_lease = builtins.listToAttrs (
    lib.mapAttrsToList (
      name: host:
      {
        name = builtins.replaceStrings [ "-" ] [ "_" ] name;
        value = {
          address = host.ip;
          mac_address = lib.toUpper host.mac;
          comment = if host.comment != "" then host.comment else name;
          server = "defconf";
        };
      }
    ) routerConfig.hosts
  );
}
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/dhcp/default.nix
git commit -m "feat(router): add terranix DHCP module"
```

---

## Task 8: Create terranix DNS module

**Files:**
- Create: `modules/terraform/routeros/dns/default.nix`

**Step 1: Create DNS resources**

```nix
{ lib, routerConfig, ... }:
let
  localDomain = routerConfig.localDomain;

  # Primary DNS records for hosts with dns=true
  primaryRecords = lib.filterAttrs (_: host: host.dns) routerConfig.hosts;

  # Alias records expanded to individual entries
  aliasEntries = lib.concatLists (
    lib.mapAttrsToList (
      _: host:
      builtins.map (alias: {
        name = alias;
        ip = host.ip;
      }) host.aliases
    ) routerConfig.hosts
  );
in
{
  resource.routeros_dns.settings = {
    allow_remote_requests = true;
    servers = routerConfig.dns.upstream;
  };

  resource.routeros_ip_dns_record =
    # FWD rule for *.local
    {
      local_fwd = {
        forward_to = routerConfig.gateway;
        regexp = ".*\\\\.${localDomain}$$";
        type = "FWD";
      };
    }
    # A records from hosts
    // builtins.listToAttrs (
      lib.mapAttrsToList (
        name: host:
        {
          name = builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
          value = {
            address = host.ip;
            name = "${name}.${localDomain}";
            type = "A";
          };
        }
      ) primaryRecords
    )
    # A records from aliases
    // builtins.listToAttrs (
      builtins.map (entry: {
        name = "alias_${builtins.replaceStrings [ "-" "." ] [ "_" "_" ] entry.name}";
        value = {
          address = entry.ip;
          name = "${entry.name}.${localDomain}";
          type = "A";
        };
      }) aliasEntries
    );
}
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/dns/default.nix
git commit -m "feat(router): add terranix DNS module"
```

---

## Task 9: Create terranix firewall module

**Files:**
- Create: `modules/terraform/routeros/firewall/default.nix`

This is the most complex module due to firewall rule ordering requirements.

**Step 1: Create firewall resources**

```nix
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
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/firewall/default.nix
git commit -m "feat(router): add terranix firewall module"
```

---

## Task 10: Create terranix system module

**Files:**
- Create: `modules/terraform/routeros/system/default.nix`

**Step 1: Create system resources**

```nix
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
```

**Step 2: Commit**

```bash
git add modules/terraform/routeros/system/default.nix
git commit -m "feat(router): add terranix system module"
```

---

## Task 11: Create terranix misc module (routeros_rest)

**Files:**
- Create: `modules/terraform/routeros/misc/default.nix`

**Step 1: Create generic REST resources for unmapped items**

```nix
{ ... }:
{
  # LCD settings (no dedicated terraform resource)
  resource.routeros_rest.lcd = {
    path = "/lcd";
    data = builtins.toJSON {
      default-screen = "log";
      enabled = "false";
      touch-screen = "disabled";
    };
  };

  # Serial port naming
  resource.routeros_rest.port_serial0 = {
    path = "/port";
    data = builtins.toJSON {
      ".id" = "*0";
      name = "serial0";
    };
  };

  # SMB default user disabled
  resource.routeros_rest.smb_user_default = {
    path = "/ip/smb/users";
    data = builtins.toJSON {
      ".id" = "*0";
      disabled = "true";
    };
  };

  # SMB default share
  resource.routeros_rest.smb_share_default = {
    path = "/ip/smb/shares";
    data = builtins.toJSON {
      ".id" = "*0";
      directory = "/pub";
    };
  };

  # Wireless security profiles default
  resource.routeros_rest.wireless_security_default = {
    path = "/interface/wireless/security-profiles";
    data = builtins.toJSON {
      ".id" = "*0";
      supplicant-identity = "MikroTik";
    };
  };
}
```

**Note:** The `routeros_rest` resource schema may differ from what's shown here. Verify the exact attributes accepted by the provider during implementation. If `routeros_rest` doesn't work for these resources, they can be safely removed -- these are low-priority settings that rarely change.

**Step 2: Commit**

```bash
git add modules/terraform/routeros/misc/default.nix
git commit -m "feat(router): add terranix misc module for routeros_rest"
```

---

## Task 12: Create `packages/router/hosts.nix`

**Files:**
- Create: `packages/router/hosts.nix`

**Step 1: Extract host data**

This data comes from `modules/home/roles/router-manager/default.nix:25-95`.

```nix
{ defaults }:
let
  ips = defaults.network.hosts;
in
{
  cap1 = {
    ip = ips.cap1;
    mac = "DC:2C:6E:18:C7:69";
    comment = "cAP floor 1";
    dns = true;
    aliases = [ ];
  };
  cap2 = {
    ip = ips.cap2;
    mac = "DC:2C:6E:18:C0:AB";
    comment = "cAP floor 2";
    dns = true;
    aliases = [ ];
  };
  monitor = {
    ip = ips.monitor;
    mac = "00:12:17:DC:98:99";
    comment = "Monitor";
    dns = true;
    aliases = [ ];
  };
  ajax = {
    ip = ips.ajax;
    mac = "38:B8:EB:C2:54:53";
    comment = "Ajax";
    dns = true;
    aliases = [ ];
  };
  doorbell = {
    ip = ips.doorbell;
    mac = "3C:E3:6B:4B:21:94";
    comment = "Doorbell";
    dns = false;
    aliases = [ ];
  };
  server = {
    ip = ips.server;
    mac = "D8:3A:DD:D7:30:67";
    comment = "Server";
    dns = true;
    aliases = [
      "radarr"
      "jellyfin"
      "qbittorrent"
      "prowlarr"
      "minidlna"
      "sonarr"
      "home-assistant"
      "zigbee2mqtt"
      "minecraft"
      "restic"
    ];
  };
  tv = {
    ip = ips.tv;
    mac = "0C:CA:FB:0B:47:EE";
    comment = "TV lan";
    dns = true;
    aliases = [ ];
  };
  tv-wifi = {
    ip = ips.tv-wifi;
    mac = "04:39:26:B6:FB:6C";
    comment = "TV wifi";
    dns = false;
    aliases = [ ];
  };
  inverter = {
    ip = ips.inverter;
    mac = "D4:27:87:27:B8:3E";
    comment = "Deye inverter";
    dns = true;
    aliases = [ ];
  };
  heatpump = {
    ip = ips.heatpump;
    mac = "EC:FA:BC:C2:EC:C6";
    comment = "Heatpump";
    dns = true;
    aliases = [ ];
  };
  "1c-key" = {
    ip = ips."1c-key";
    mac = "08:00:27:98:89:98";
    comment = "1C HASP Licence Manager";
    dns = true;
    aliases = [ ];
  };
}
```

**Step 2: Commit**

```bash
git add packages/router/hosts.nix
git commit -m "feat(router): extract host data to packages/router/hosts.nix"
```

---

## Task 13: Create `packages/router/default.nix`

**Files:**
- Create: `packages/router/default.nix`

**Step 1: Create the package entry point**

```nix
{
  lib,
  pkgs,
  system,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  net = lib.${namespace};

  routerConfig = {
    # Network (from lib/defaults)
    subnet = defaults.network.subnet;
    gateway = defaults.network.gateway;
    dhcpRange = defaults.network.dhcpRange;
    networkAddress = net.networkAddress defaults.network.gateway;
    prefixLength = net.prefixLength defaults.network.subnet;
    localDomain = defaults.network.domains.local;

    # WiFi
    wifi = {
      ssid = defaults.network.wifi.ssid;
    };

    # DNS
    dns = {
      upstream = defaults.network.dns.upstream;
    };

    # Hardware
    bridge = {
      adminMac = "08:55:31:E9:21:73";
    };

    lte = {
      apn = "ks";
      name = "Kyivstar";
    };

    ovpn = {
      macAddress = "FE:24:A6:AA:80:85";
    };

    # System
    timezone = defaults.locale.timeZone;

    # Hosts
    hosts = import ./hosts.nix { inherit defaults; };

    # Firewall address lists
    firewallAddressLists = {
      tv = [
        "${defaults.network.hosts.tv}/32"
        "${defaults.network.hosts.tv-wifi}/32"
      ];
    };
  };

  base = mkTerranixDerivation {
    inherit pkgs system;
    extraArgs = {
      inherit routerConfig;
    };
    terraformModulesPath = ../../modules/terraform/routeros;
    modules = [ ];
    stateDir = toString ./.; # State lives here, encrypted by OpenTofu natively
  };

  # SSH-based backup script (preserved from old module)
  sshAlias = "router";
  configDir = "\${XDG_CONFIG_HOME:-$HOME/.config}/mikrotik";

  backup = pkgs.writeShellScriptBin "backup" ''
    set -euo pipefail

    ROUTER="${sshAlias}"
    BACKUP_DIR="${configDir}"

    usage() {
      echo "Usage: router-backup [OPTIONS]"
      echo ""
      echo "Create a backup of the MikroTik router and download it"
      echo ""
      echo "Options:"
      echo "  -o, --output DIR  Backup directory (default: \$XDG_CONFIG_HOME/mikrotik)"
      echo "  -h, --help        Show this help"
      exit 0
    }

    while [[ $# -gt 0 ]]; do
      case $1 in
        -o|--output) BACKUP_DIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
      esac
    done

    mkdir -p "$BACKUP_DIR"

    BACKUP_NAME="nix-$(date +%Y%m%d-%H%M%S)"

    echo "Creating backup on router..."
    ssh "$ROUTER" "/system backup save name=$BACKUP_NAME" || {
      echo "Error: Backup failed"
      exit 1
    }

    echo "Downloading backup to $BACKUP_DIR/$BACKUP_NAME.backup..."
    scp "$ROUTER:/$BACKUP_NAME.backup" "$BACKUP_DIR/$BACKUP_NAME.backup" || {
      echo "Error: Failed to download backup file"
      exit 1
    }

    echo "Backup saved to: $BACKUP_DIR/$BACKUP_NAME.backup"
  '';
in
base // { inherit backup; }
```

**Step 2: Verify package builds**

Run: `nix build .#router --dry-run`
Expected: Shows build plan without errors

**Step 3: Test JSON generation**

Run: `nix run .#router`
Expected: Prints pretty-printed terraform JSON with all resources

**Step 4: Commit**

```bash
git add packages/router/default.nix
git commit -m "feat(router): add packages/router entry point"
```

---

## Task 14: Add SOPS secrets for router

**Files:**
- Modify: `modules/home/secrets.yaml` (via `sops`)

**Step 1: Add secrets**

Run `sops modules/home/secrets.yaml` and add:
- `router-api-password` -- the password for the RouterOS API user
- `router-state-passphrase` -- passphrase for OpenTofu state encryption (min 16 chars, generate with `openssl rand -base64 32`)

**Step 2: Commit**

```bash
git add modules/home/secrets.yaml
git commit -m "feat(router): add SOPS secrets for router API and state encryption"
```

---

## Task 15: Create import configuration (manual, requires router access)

**Files:**
- Create: `packages/router/imports.nix`

This is a temporary file used during migration. Resource IDs need to be discovered from the router first.

**Step 1: Discover resource IDs from router**

Run these commands to find internal IDs:
```bash
ssh router "/interface bridge print terse"
ssh router "/interface list print terse"
ssh router "/interface list member print terse"
ssh router "/interface bridge port print terse"
ssh router "/ip pool print terse"
ssh router "/ip dhcp-server print terse"
ssh router "/ip dhcp-server lease print terse"
ssh router "/ip dns static print terse"
ssh router "/ip firewall filter print terse"
ssh router "/ip firewall nat print terse"
ssh router "/ip firewall address-list print terse"
ssh router "/ip address print terse"
ssh router "/caps-man channel print terse"
ssh router "/caps-man datapath print terse"
ssh router "/caps-man security print terse"
ssh router "/caps-man configuration print terse"
ssh router "/caps-man provisioning print terse"
ssh router "/system identity print"
```

**Step 2: Create imports.nix with discovered IDs**

```nix
# TEMPORARY: Remove after successful import
{ ... }:
{
  # Fill in actual IDs from router discovery above
  # Named resources use their name, unnamed use *hex IDs
  import = [
    # Bridge
    { to = "routeros_interface_bridge.bridge"; id = "*1"; }

    # Interface lists
    { to = "routeros_interface_list.WAN"; id = "*2000001"; }
    { to = "routeros_interface_list.LAN"; id = "*2000002"; }

    # TODO: Fill in remaining resource IDs from router discovery
    # Each resource needs: { to = "resource_type.name"; id = "<router_id>"; }
  ];
}
```

**Step 3: Run import**

To use imports.nix, temporarily modify `packages/router/default.nix` to include it in modules:
```nix
modules = [ ./imports.nix ];
```

Then run:
```bash
export TF_VAR_routeros_password=$(sops -d --extract '["router-api-password"]' modules/home/secrets.yaml)
export TF_VAR_wifi_password=$(sops -d --extract '["system-network-wifi-password"]' modules/home/secrets.yaml)
export TF_VAR_state_passphrase=$(sops -d --extract '["router-state-passphrase"]' modules/home/secrets.yaml)
nix run .#router.apply
```

**Step 4: Verify zero drift**

Run: `nix run .#router.plan`
Expected: "No changes. Your infrastructure matches the configuration."

**Step 5: Remove imports**

Remove `./imports.nix` from the modules list in `packages/router/default.nix` (revert to `modules = [ ];`).

**Step 6: Commit state and import config**

After a successful import, the OpenTofu-encrypted state file `packages/router/terraform.tfstate` will have been created.

```bash
git add packages/router/imports.nix packages/router/default.nix packages/router/terraform.tfstate
git commit -m "feat(router): import existing router state into OpenTofu"
```

---

## Task 16: Update justfile

**Files:**
- Modify: `justfile:78-93` (deploy recipe router case)
- Modify: `justfile:314-351` (router management section)

**Step 1: Update deploy recipe**

Replace lines 86-88 of the deploy recipe:

```just
    @if [ "{{hostname}}" = "router" ]; then \
        echo "🌐 Deploying to MikroTik router..."; \
        router-import {{extra_opts}}; \
```

With:

```just
    @if [ "{{hostname}}" = "router" ]; then \
        echo "🌐 Deploying to MikroTik router..."; \
        nix run .#router.apply; \
```

**Step 2: Replace router management section**

Replace lines 314-351 with:

```just
# ============================================
# Router Management (MikroTik via OpenTofu)
# ============================================

# Show generated terraform JSON for router
router-show:
    nix run .#router

# Plan router configuration changes (dry-run)
router-plan:
    nix run .#router.plan

# Apply router configuration changes
router-apply:
    nix run .#router.apply

# Destroy router terraform state (dangerous!)
router-destroy:
    nix run .#router.destroy

# Create SSH backup of router
router-backup *opts="":
    nix run .#router.backup -- {{opts}}

# Show environment setup for router secrets
router-env:
    @echo "Run the following to set up environment:"
    @echo '  export TF_VAR_routeros_password=$$(sops -d --extract '"'"'["router-api-password"]'"'"' modules/home/secrets.yaml)'
    @echo '  export TF_VAR_wifi_password=$$(sops -d --extract '"'"'["system-network-wifi-password"]'"'"' modules/home/secrets.yaml)'
    @echo '  export TF_VAR_state_passphrase=$$(sops -d --extract '"'"'["router-state-passphrase"]'"'"' modules/home/secrets.yaml)'

# Show router management help
router-help:
    @echo "Router Management Commands (OpenTofu-based):"
    @echo ""
    @echo "  just router-env              Show environment setup for secrets"
    @echo "  just router-show             Show generated terraform JSON"
    @echo "  just router-plan             Plan changes (dry-run)"
    @echo "  just router-apply            Apply changes to router"
    @echo "  just router-backup           Create SSH backup of router"
    @echo "  just router-destroy          Destroy terraform state (dangerous!)"
    @echo ""
    @echo "Prerequisites:"
    @echo "  - Old API enabled on router (/ip service set api disabled=no address=10.0.0.0/24)"
    @echo "  - SOPS secrets: router-api-password, system-network-wifi-password, router-state-passphrase"
    @echo "  - Environment: run 'just router-env' and follow instructions"
    @echo ""
    @echo "State Management:"
    @echo "  - State is natively encrypted by OpenTofu (PBKDF2 + AES-GCM) at packages/router/terraform.tfstate"
    @echo "  - Commit the updated state file after apply: git add packages/router/terraform.tfstate && git commit"
    @echo ""
    @echo "Workflow:"
    @echo "  1. Run 'just router-env' and export the secrets"
    @echo "  2. Run 'just router-plan' to preview changes"
    @echo "  3. Run 'just router-apply' to apply changes"
    @echo "  4. Commit updated state: git add packages/router/terraform.tfstate && git commit"
```

**Step 3: Commit**

```bash
git add justfile
git commit -m "feat(router): update justfile for OpenTofu workflow"
```

---

## Task 17: Simplify router-manager role

**Files:**
- Modify: `modules/home/roles/router-manager/default.nix`

**Step 1: Remove router module configuration, keep winbox4**

Replace the entire file content with:

```nix
{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.router-manager;
in
{
  options.${namespace}.roles.router-manager = {
    enable = mkEnableOption "Enable router manager configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.winbox4 ];
  };
}
```

**Step 2: Commit**

```bash
git add modules/home/roles/router-manager/default.nix
git commit -m "refactor(router): simplify router-manager role to winbox4 only"
```

---

## Task 18: Delete old router module

**Files:**
- Delete: `modules/home/system/networking/router/default.nix`
- Delete: `modules/home/system/networking/router/config.nix`
- Delete: `modules/home/system/networking/router/RouterOS.md`

**Step 1: Remove old files**

```bash
rm modules/home/system/networking/router/default.nix
rm modules/home/system/networking/router/config.nix
rm modules/home/system/networking/router/RouterOS.md
rmdir modules/home/system/networking/router/
```

**Step 2: Verify build still works**

Run: `nix flake check`
Expected: No errors (the old module options are no longer referenced)

If there are errors about missing options, check if any other module references `nix-config.system.networking.router`. Search:
```bash
grep -r "system.networking.router" modules/
```

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor(router): remove old .rsc script generator"
```

---

## Task 19: Final verification

**Step 1: Format all new files**

Run: `just format`

**Step 2: Run lint checks**

Run: `just lint-check`
Expected: All checks pass

**Step 3: Verify package output**

Run: `nix run .#router`
Expected: Complete terraform JSON with all resources

**Step 4: Verify passthru scripts exist**

Run: `nix run .#router.plan -- --help 2>&1 | head -5`
Expected: terraform plan help or env var error (if secrets not set)

**Step 5: Commit any formatting changes**

```bash
git add -A
git commit -m "style(router): format terranix modules"
```

---

## Execution Order Summary

1. Add terranix flake input
2. Create `lib/terraform/default.nix` (mkTerranixDerivation with OpenTofu)
3. Create `modules/terraform/routeros/provider/default.nix` (with encryption config)
4. Create `modules/terraform/routeros/bridge/default.nix`
5. Create `modules/terraform/routeros/interfaces/default.nix`
6. Create `modules/terraform/routeros/capsman/default.nix`
7. Create `modules/terraform/routeros/dhcp/default.nix`
8. Create `modules/terraform/routeros/dns/default.nix`
9. Create `modules/terraform/routeros/firewall/default.nix`
10. Create `modules/terraform/routeros/system/default.nix`
11. Create `modules/terraform/routeros/misc/default.nix`
12. Create `packages/router/hosts.nix`
13. Create `packages/router/default.nix` + verify build
14. Add SOPS secrets (`router-api-password`, `router-state-passphrase`)
15. Create import config + run migration (manual, requires router access)
16. Update justfile
17. Simplify router-manager role
18. Delete old router module
19. Final verification + formatting
