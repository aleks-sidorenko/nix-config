# nix-routeros Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone Nix flake that provides NixOS-module-style options for configuring MikroTik RouterOS routers via terranix.

**Architecture:** Plain flake exporting terranix modules with `routeros.*` options. Each module defines options and produces `config.resource.*` attrsets consumed by terranix. An opinionated `presets.router` layer provides home-router defaults.

**Tech Stack:** Nix (module system), terranix, OpenTofu, terraform-routeros provider

**Spec:** `docs/specs/2026-03-21-nix-routeros-design.md`

**Repo location:** `~/Projects/Self/nix-routeros`

---

## File Map

```
~/Projects/Self/nix-routeros/
├── flake.nix                    # Inputs (terranix, nixpkgs), all outputs
├── modules/
│   ├── default.nix              # Imports all modules, defines routeros.hosts + _internal options
│   ├── connection.nix           # routeros.connection.* → provider + variables
│   ├── system.nix               # routeros.system.* → identity, clock, services, ip settings
│   ├── bridge.nix               # routeros.bridge.* → bridge interface + ports
│   ├── interfaces.nix           # routeros.interfaces.* → WAN, LTE, interface lists
│   ├── dhcp.nix                 # routeros.network.dhcp.* → server, client, leases from hosts
│   ├── dns.nix                  # routeros.dns.* → records, aliases, forwarding from hosts
│   ├── firewall.nix             # routeros.firewall.* → filter rules, NAT, address lists
│   └── wifi.nix                 # routeros.wifi.* → CAPsMAN channels, security, provisioning
├── presets/
│   └── router.nix               # Opinionated defaults, imports modules/default.nix
├── lib/
│   ├── helpers.nix              # sanitizeName, networkAddress, prefixLength
│   └── types.nix                # hostType, firewallRuleType submodule types
├── templates/
│   └── default/
│       ├── flake.nix            # Starter flake for `nix flake init`
│       └── router.nix           # Example config with comments
└── examples/
    └── basic/
        ├── flake.nix            # Minimal working example
        └── config.nix           # Example routeros.* config
```

---

## Chunk 1: Repository scaffolding & lib

### Task 1: Initialize repository

**Files:**
- Create: `~/Projects/Self/nix-routeros/.gitignore`
- Create: `~/Projects/Self/nix-routeros/flake.nix`

- [ ] **Step 1: Create repo and initialize git**

```bash
mkdir -p ~/Projects/Self/nix-routeros
cd ~/Projects/Self/nix-routeros
git init
```

- [ ] **Step 2: Create .gitignore**

```
result
.direnv
```

- [ ] **Step 3: Create initial flake.nix**

```nix
{
  description = "NixOS-module-style interface for configuring MikroTik RouterOS via terranix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, terranix, ... }:
    let
      inherit (nixpkgs) lib;
      helpers = import ./lib/helpers.nix { inherit lib; };
    in
    {
      # Terranix modules — system-independent
      terranixModules = {
        default = ./modules;
        connection = ./modules/connection.nix;
        system = ./modules/system.nix;
        bridge = ./modules/bridge.nix;
        interfaces = ./modules/interfaces.nix;
        dhcp = ./modules/dhcp.nix;
        dns = ./modules/dns.nix;
        firewall = ./modules/firewall.nix;
        wifi = ./modules/wifi.nix;
      };

      # Presets
      presets.router = ./presets/router.nix;

      # Lib helpers
      lib = helpers // {
        mkRouterDerivation = { pkgs, system, name ? "router", modules ? [], stateDir ? ".", secretsFile ? null, secrets ? {} }:
          let
            terraformConfiguration = terranix.lib.terranixConfiguration {
              inherit system;
              extraArgs = { inherit lib pkgs; };
              modules = [ self.presets.router ] ++ modules;
            };

            tofu = "${pkgs.opentofu}/bin/tofu";
            sops = "${pkgs.sops}/bin/sops";

            resolveRoot = ''
              if [[ -z "''${FLAKE_DIR:-}" ]]; then
                echo "Error: FLAKE_DIR not set. Export it to the flake root directory."
                exit 1
              fi
              REPO_ROOT="$FLAKE_DIR"
            '';

            loadSecrets =
              if secretsFile != null && secrets != {} then
                lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (
                    envVar: sopsKey:
                    ''export ${envVar}=$(${sops} -d --extract '["${sopsKey}"]' "$REPO_ROOT/${secretsFile}")''
                  ) secrets
                )
              else
                "";

            tfSetup = ''
              cd "$REPO_ROOT/${stateDir}"
              cp -f ${terraformConfiguration} config.tf.json
            '';

            show = pkgs.writeShellScriptBin "${name}-show" ''
              set -euo pipefail
              cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
            '';

            plan = pkgs.writeShellScriptBin "${name}-plan" ''
              set -euo pipefail
              ${resolveRoot}
              ${loadSecrets}
              ${tfSetup}
              ${tofu} init -input=false
              ${tofu} plan
            '';

            apply = pkgs.writeShellScriptBin "${name}-apply" ''
              set -euo pipefail
              ${resolveRoot}
              ${loadSecrets}
              ${tfSetup}
              ${tofu} init -input=false
              ${tofu} apply
            '';

            destroy = pkgs.writeShellScriptBin "${name}-destroy" ''
              set -euo pipefail
              ${resolveRoot}
              ${loadSecrets}
              ${tfSetup}
              ${tofu} init -input=false
              ${tofu} destroy
            '';
          in
          show // { inherit plan apply destroy; };
      };

      # Templates
      templates.default = {
        path = ./templates/default;
        description = "Basic nix-routeros configuration";
      };
    };
}
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: initial flake with inputs and output structure"
```

---

### Task 2: Create lib helpers

**Files:**
- Create: `~/Projects/Self/nix-routeros/lib/helpers.nix`
- Create: `~/Projects/Self/nix-routeros/lib/types.nix`

- [ ] **Step 1: Create lib/helpers.nix**

Unified name sanitization (replaces both `-` and `.` with `_`, prepends `_` for digit-leading names), plus network math helpers extracted from `nix-config/lib/net/`.

```nix
{ lib }:
{
  # Sanitize a name for use as a Terraform resource identifier.
  # Replaces `-` and `.` with `_`, prepends `_` if name starts with a digit.
  sanitizeName =
    name:
    let
      sanitized = builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
    in
    if builtins.match "[0-9].*" sanitized != null then "_${sanitized}" else sanitized;

  # Derive network address from gateway IP (assumes last octet is the host part).
  # "10.0.0.1" -> "10.0.0.0"
  networkAddress =
    gateway:
    let
      parts = lib.splitString "." gateway;
    in
    "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}.${builtins.elemAt parts 2}.0";

  # Extract prefix length from CIDR notation.
  # "10.0.0.0/24" -> 24
  prefixLength =
    cidr:
    let
      parts = lib.splitString "/" cidr;
    in
    lib.toInt (builtins.elemAt parts 1);
}
```

- [ ] **Step 2: Create lib/types.nix**

Custom submodule types for `routeros.hosts` and firewall rules.

```nix
{ lib }:
let
  inherit (lib) mkOption types;
in
{
  hostType = types.submodule {
    options = {
      ip = mkOption {
        type = types.str;
        description = "IP address of the host.";
      };
      mac = mkOption {
        type = types.str;
        description = "MAC address of the host.";
      };
      comment = mkOption {
        type = types.str;
        default = "";
        description = "Comment for DHCP lease and DNS record.";
      };
      dhcp = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create a static DHCP lease.";
      };
      dns = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create a DNS A record.";
      };
      aliases = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional DNS names pointing to this host's IP.";
      };
    };
  };

  firewallRuleType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      name = mkOption {
        type = types.str;
        description = "Unique resource name for this rule.";
      };
      action = mkOption {
        type = types.str;
        description = "Firewall action (accept, drop, fasttrack-connection, etc.).";
      };
      chain = mkOption {
        type = types.str;
        description = "Firewall chain (input, forward, srcnat, dstnat).";
      };
    };
  };

  natRuleType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      name = mkOption {
        type = types.str;
        description = "Unique resource name for this NAT rule.";
      };
      action = mkOption {
        type = types.str;
        description = "NAT action (masquerade, redirect, dst-nat, etc.).";
      };
      chain = mkOption {
        type = types.str;
        description = "NAT chain (srcnat, dstnat).";
      };
    };
  };
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/
git commit -m "feat: add lib helpers (sanitizeName, network math, option types)"
```

---

## Chunk 2: Core modules (connection, system, bridge, interfaces)

### Task 3: Create modules/default.nix (module aggregator + hosts option)

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/default.nix`

- [ ] **Step 1: Create modules/default.nix**

This file imports all feature modules and defines the shared `routeros.hosts` option that multiple modules consume.

```nix
{ lib, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  customTypes = import ../lib/types.nix { inherit lib; };
in
{
  imports = [
    ./connection.nix
    ./system.nix
    ./bridge.nix
    ./interfaces.nix
    ./dhcp.nix
    ./dns.nix
    ./firewall.nix
    ./wifi.nix
  ];

  options.routeros = {
    hosts = lib.mkOption {
      type = lib.types.attrsOf customTypes.hostType;
      default = { };
      description = "Host inventory. Drives DHCP leases, DNS records, and aliases.";
    };

    # Shared network option consumed by system.nix and dhcp.nix
    network.subnet = lib.mkOption {
      type = lib.types.str;
      description = "Network subnet in CIDR notation (e.g. 10.0.0.0/24).";
    };

    # Internal: expose helpers to other modules
    _lib = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      default = helpers;
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/default.nix
git commit -m "feat: add modules/default.nix with hosts option and module imports"
```

---

### Task 4: Create connection module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/connection.nix`

- [ ] **Step 1: Create modules/connection.nix**

Produces the terraform provider block and variables from `routeros.connection.*` options.

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.connection;
in
{
  options.routeros.connection = {
    gateway = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.1";
      description = "Router IP address for API connection.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "RouterOS API username.";
    };

    providerVersion = lib.mkOption {
      type = lib.types.str;
      default = "~> 1.99";
      description = "RouterOS Terraform provider version constraint.";
    };

    scheme = lib.mkOption {
      type = lib.types.enum [ "api" "apis" ];
      default = "api";
      description = "API connection scheme (api for plaintext, apis for TLS).";
    };
  };

  config = {
    terraform = {
      required_providers.routeros = {
        source = "terraform-routeros/routeros";
        version = cfg.providerVersion;
      };
    };

    provider.routeros = {
      hosturl = "${cfg.scheme}://${cfg.gateway}";
      username = "\${var.routeros_username}";
      password = "\${var.routeros_password}";
    };

    variable = {
      routeros_username = {
        type = "string";
        default = cfg.username;
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
        default = "";
      };
      state_passphrase = {
        type = "string";
        sensitive = true;
        description = "Passphrase for OpenTofu state encryption (min 16 chars)";
        default = "";
      };
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/connection.nix
git commit -m "feat: add connection module (provider, variables)"
```

---

### Task 5: Create system module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/system.nix`

- [ ] **Step 1: Create modules/system.nix**

Covers identity, clock, IP address, services, IP settings, IPv6, MAC server, IPsec, BFD, neighbor discovery.

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.system;
  connCfg = config.routeros.connection;
  helpers = config.routeros._lib;
  networkAddress = helpers.networkAddress connCfg.gateway;
  prefixLength = helpers.prefixLength config.routeros.network.subnet;

  mkServiceOpt = name: defaults: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = defaults.enable or true;
      description = "Whether to enable the ${name} service.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = defaults.port;
      description = "Port for the ${name} service.";
    };
    allowedAddresses = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = defaults.allowedAddresses or null;
      description = "Restrict ${name} to this address/subnet. null means unrestricted.";
    };
  };
in
{
  options.routeros.system = {
    identity = lib.mkOption {
      type = lib.types.str;
      default = "Router";
      description = "Router system identity (hostname).";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "System timezone.";
    };

    services = {
      ssh = mkServiceOpt "SSH" { port = 22; };
      winbox = mkServiceOpt "Winbox" { port = 8291; };
      api = mkServiceOpt "API" { port = 8728; };
      ftp = mkServiceOpt "FTP" { enable = false; port = 21; };
      telnet = mkServiceOpt "Telnet" { enable = false; port = 23; };
      www = mkServiceOpt "WWW" { enable = false; port = 80; };
      api-ssl = mkServiceOpt "API-SSL" { enable = false; port = 8729; };
    };

    ipSettings = {
      maxNeighborEntries = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = "Maximum number of neighbor entries.";
      };
    };

    ipv6 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable IPv6.";
      };
      acceptRouterAdvertisements = lib.mkOption {
        type = lib.types.str;
        default = "yes";
        description = "Accept router advertisements (yes/no/yes-if-forwarding-disabled).";
      };
      maxNeighborEntries = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = "Maximum IPv6 neighbor entries.";
      };
    };

    macServer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable MAC server and MAC server winbox.";
      };
      allowedInterfaceList = lib.mkOption {
        type = lib.types.str;
        default = "LAN";
        description = "Interface list allowed for MAC server access.";
      };
    };

    ipsec = {
      dpdInterval = lib.mkOption {
        type = lib.types.str;
        default = "2m";
        description = "Dead Peer Detection interval.";
      };
      dpdMaxFailures = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Maximum DPD failures before peer is considered dead.";
      };
    };

    bfd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable BFD (Bidirectional Forwarding Detection).";
    };

    neighborDiscovery = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable neighbor discovery.";
      };
      interfaceList = lib.mkOption {
        type = lib.types.str;
        default = "LAN";
        description = "Interface list for neighbor discovery.";
      };
    };
  };

  config = {
    resource = {
      routeros_system_identity.router = {
        name = cfg.identity;
      };

      routeros_system_clock.default = {
        time_zone_name = cfg.timezone;
        time_zone_autodetect = false;
      };

      routeros_ip_address.bridge = {
        address = "${connCfg.gateway}/${toString prefixLength}";
        interface = "bridge";
        network = networkAddress;
        comment = "defconf";
      };

      routeros_ip_service = let
        mkSvc = name: numbers: svcCfg: {
          inherit numbers;
          port = svcCfg.port;
          disabled = !svcCfg.enable;
        } // lib.optionalAttrs (svcCfg.enable && svcCfg.allowedAddresses != null) {
          address = svcCfg.allowedAddresses;
        };
      in {
        ftp = mkSvc "ftp" "ftp" cfg.services.ftp;
        ssh = mkSvc "ssh" "ssh" cfg.services.ssh;
        telnet = mkSvc "telnet" "telnet" cfg.services.telnet;
        www = mkSvc "www" "www" cfg.services.www;
        winbox = mkSvc "winbox" "winbox" cfg.services.winbox;
        api = mkSvc "api" "api" cfg.services.api;
        api_ssl = mkSvc "api-ssl" "api-ssl" cfg.services.api-ssl;
      };

      routeros_ip_neighbor_discovery_settings.default = {
        discover_interface_list = cfg.neighborDiscovery.interfaceList;
      };

      routeros_ip_settings.default = {
        max_neighbor_entries = cfg.ipSettings.maxNeighborEntries;
      };

      routeros_ipv6_settings.default = {
        accept_router_advertisements = cfg.ipv6.acceptRouterAdvertisements;
        disable_ipv6 = !cfg.ipv6.enable;
        max_neighbor_entries = cfg.ipv6.maxNeighborEntries;
      };

      routeros_ip_ipsec_profile.default = {
        name = "default";
        dpd_interval = cfg.ipsec.dpdInterval;
        dpd_maximum_failures = cfg.ipsec.dpdMaxFailures;
      };

      routeros_routing_bfd_configuration.default = {
        disabled = !cfg.bfd.enable;
      };

      routeros_tool_mac_server.default = {
        allowed_interface_list = cfg.macServer.allowedInterfaceList;
      };

      routeros_tool_mac_server_winbox.default = {
        allowed_interface_list = cfg.macServer.allowedInterfaceList;
      };
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/system.nix
git commit -m "feat: add system module (identity, clock, services, IP settings)"
```

---

### Task 6: Create bridge module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/bridge.nix`

- [ ] **Step 1: Create modules/bridge.nix**

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.bridge;
in
{
  options.routeros.bridge = {
    enable = lib.mkEnableOption "bridge interface";

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces to add as bridge ports.";
      example = [ "ether2" "ether3" "ether4" "sfp1" ];
    };

    adminMac = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Manual admin MAC address for the bridge. If null, auto-mac is used.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_interface_bridge.bridge = {
        name = "bridge";
        auto_mac = cfg.adminMac == null;
        comment = "defconf";
        port_cost_mode = "short";
      } // lib.optionalAttrs (cfg.adminMac != null) {
        admin_mac = cfg.adminMac;
      };

      routeros_interface_bridge_port = builtins.listToAttrs (
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
        }) cfg.ports
      );
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/bridge.nix
git commit -m "feat: add bridge module"
```

---

### Task 7: Create interfaces module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/interfaces.nix`

- [ ] **Step 1: Create modules/interfaces.nix**

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.interfaces;
  lteCfg = cfg.lte;
in
{
  options.routeros.interfaces = {
    wan = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "ether1" ];
      description = "WAN interfaces.";
    };

    lte = {
      enable = lib.mkEnableOption "LTE interface";

      apn = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "APN for LTE connection.";
      };

      provider = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "LTE provider name.";
      };
    };

    lists = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Additional interface list memberships beyond auto-generated WAN/LAN.";
    };
  };

  config = {
    resource = {
      # WAN ethernet interfaces
      routeros_interface_ethernet = builtins.listToAttrs (
        builtins.map (iface: {
          name = iface;
          value = {
            name = iface;
            factory_name = iface;
            comment = "WAN";
          };
        }) cfg.wan
      );

      # Interface lists
      routeros_interface_list = {
        WAN = { name = "WAN"; comment = "defconf"; };
        LAN = { name = "LAN"; comment = "defconf"; };
      };

      # List members: bridge→LAN, WAN interfaces→WAN, LTE→WAN (if enabled)
      routeros_interface_list_member =
        { bridge_LAN = { interface = "bridge"; list = "LAN"; comment = "defconf"; }; }
        // builtins.listToAttrs (
          builtins.map (iface: {
            name = "${iface}_WAN";
            value = { interface = iface; list = "WAN"; comment = "defconf"; };
          }) cfg.wan
        )
        // lib.optionalAttrs lteCfg.enable {
          lte1_WAN = { interface = "lte1"; list = "WAN"; };
        };

      # LTE APN
      routeros_interface_lte_apn = lib.mkIf lteCfg.enable {
        default = {
          apn = lteCfg.apn;
          ip_type = "ipv4";
          ipv6_interface = "bridge";
          name = lteCfg.provider;
          use_network_apn = false;
        };
      };
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/interfaces.nix
git commit -m "feat: add interfaces module (WAN, LTE, interface lists)"
```

---

## Chunk 3: Network modules (DHCP, DNS, firewall)

### Task 8: Create DHCP module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/dhcp.nix`

- [ ] **Step 1: Create modules/dhcp.nix**

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.network.dhcp;
  connCfg = config.routeros.connection;
  netCfg = config.routeros.network;
  hosts = config.routeros.hosts;
  helpers = config.routeros._lib;
  wanInterfaces = config.routeros.interfaces.wan;
in
{
  # Note: routeros.network.subnet is declared in modules/default.nix (shared option)
  options.routeros.network = {
    dhcp = {
      server = {
        enable = lib.mkEnableOption "DHCP server";

        range = lib.mkOption {
          type = lib.types.str;
          description = "DHCP address pool range (e.g. 10.0.0.50-10.0.0.250).";
        };

        leaseTime = lib.mkOption {
          type = lib.types.str;
          default = "1d";
          description = "DHCP lease duration.";
        };
      };

      client = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable DHCP client on WAN interface for upstream connectivity.";
        };

        interface = lib.mkOption {
          type = lib.types.str;
          default = builtins.elemAt wanInterfaces 0;
          defaultText = "First WAN interface";
          description = "Interface for DHCP client.";
        };
      };
    };
  };

  config = {
    resource = lib.mkMerge [
      # DHCP server
      (lib.mkIf cfg.server.enable {
        routeros_ip_pool.dhcp = {
          name = "dhcp";
          ranges = [ cfg.server.range ];
        };

        routeros_ip_dhcp_server.defconf = {
          name = "defconf";
          address_pool = "dhcp";
          interface = "bridge";
          lease_time = cfg.server.leaseTime;
          dynamic_lease_identifiers = "client-mac,client-id";
        };

        routeros_ip_dhcp_server_network.defconf = {
          address = netCfg.subnet;
          gateway = connCfg.gateway;
          dns_server = [ connCfg.gateway ];
          netmask = toString (helpers.prefixLength netCfg.subnet);
          comment = "defconf";
        };

        # Static leases from hosts
        routeros_ip_dhcp_server_lease = builtins.listToAttrs (
          lib.mapAttrsToList (name: host: {
            name = helpers.sanitizeName name;
            value = {
              address = host.ip;
              mac_address = lib.toUpper host.mac;
              comment = if host.comment != "" then host.comment else name;
              server = "defconf";
            };
          }) (lib.filterAttrs (_: host: host.dhcp) hosts)
        );
      })

      # DHCP client on WAN
      (lib.mkIf cfg.client.enable {
        routeros_ip_dhcp_client.${cfg.client.interface} = {
          interface = cfg.client.interface;
          comment = "defconf";
        };
      })
    ];
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/dhcp.nix
git commit -m "feat: add DHCP module (server, client, host-driven leases)"
```

---

### Task 9: Create DNS module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/dns.nix`

- [ ] **Step 1: Create modules/dns.nix**

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.dns;
  connCfg = config.routeros.connection;
  hosts = config.routeros.hosts;
  helpers = config.routeros._lib;

  primaryRecords = lib.filterAttrs (_: host: host.dns) hosts;

  aliasEntries = lib.concatLists (
    lib.mapAttrsToList (
      _: host:
      builtins.map (alias: {
        name = alias;
        inherit (host) ip;
      }) host.aliases
    ) hosts
  );
in
{
  options.routeros.dns = {
    enable = lib.mkEnableOption "DNS configuration";

    upstream = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "8.8.8.8" "4.4.4.4" ];
      description = "Upstream DNS servers.";
    };

    localDomain = lib.mkOption {
      type = lib.types.str;
      default = "local";
      description = "Local domain for host DNS records (e.g. server.local).";
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional DNS aliases. Keys are DNS names, values are target host names from routeros.hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_dns.settings = {
        allow_remote_requests = true;
        servers = cfg.upstream;
      };

      routeros_ip_dns_record =
        # FWD rule for *.local — RouterOS regex escaping handled here
        {
          local_fwd = {
            forward_to = connCfg.gateway;
            regexp = ".*\\\\.${cfg.localDomain}$$";
            type = "FWD";
          };
        }
        # A records from hosts with dns=true
        // builtins.listToAttrs (
          lib.mapAttrsToList (name: host: {
            name = helpers.sanitizeName name;
            value = {
              address = host.ip;
              name = "${name}.${cfg.localDomain}";
              type = "A";
            };
          }) primaryRecords
        )
        # A records from host aliases
        // builtins.listToAttrs (
          builtins.map (entry: {
            name = "alias_${helpers.sanitizeName entry.name}";
            value = {
              address = entry.ip;
              name = "${entry.name}.${cfg.localDomain}";
              type = "A";
            };
          }) aliasEntries
        )
        # A records from dns.aliases (name -> target host from routeros.hosts)
        // builtins.listToAttrs (
          lib.mapAttrsToList (aliasName: hostName: {
            name = "alias_${helpers.sanitizeName aliasName}";
            value = {
              address = hosts.${hostName}.ip;
              name = "${aliasName}.${cfg.localDomain}";
              type = "A";
            };
          }) cfg.aliases
        );
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/dns.nix
git commit -m "feat: add DNS module (records, aliases, local forwarding)"
```

---

### Task 10: Create firewall module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/firewall.nix`

- [ ] **Step 1: Create modules/firewall.nix**

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.firewall;
  helpers = config.routeros._lib;

  # Preset default filter rules (generic home router rules only).
  # Device-specific rules like TV traffic blocking go in consumer's filterRules.
  presetFilterRules = [
    { name = "input_accept_established"; action = "accept"; chain = "input"; comment = "defconf: accept established,related,untracked"; connection_state = "established,related,untracked"; }
    { name = "input_drop_invalid"; action = "drop"; chain = "input"; comment = "defconf: drop invalid"; connection_state = "invalid"; }
    { name = "input_accept_icmp"; action = "accept"; chain = "input"; comment = "defconf: accept ICMP"; protocol = "icmp"; }
    { name = "input_accept_loopback"; action = "accept"; chain = "input"; comment = "defconf: accept to local loopback (for CAPsMAN)"; dst_address = "127.0.0.1"; }
    { name = "input_drop_non_lan"; action = "drop"; chain = "input"; comment = "defconf: drop all not coming from LAN"; in_interface_list = "!LAN"; }
    { name = "forward_accept_ipsec_in"; action = "accept"; chain = "forward"; comment = "defconf: accept in ipsec policy"; ipsec_policy = "in,ipsec"; }
    { name = "forward_accept_ipsec_out"; action = "accept"; chain = "forward"; comment = "defconf: accept out ipsec policy"; ipsec_policy = "out,ipsec"; }
    { name = "forward_fasttrack"; action = "fasttrack-connection"; chain = "forward"; comment = "defconf: fasttrack"; connection_state = "established,related"; }
    { name = "forward_accept_established"; action = "accept"; chain = "forward"; comment = "defconf: accept established,related, untracked"; connection_state = "established,related,untracked"; }
    { name = "forward_drop_invalid"; action = "drop"; chain = "forward"; comment = "defconf: drop invalid"; connection_state = "invalid"; }
    { name = "forward_drop_wan_not_dstnat"; action = "drop"; chain = "forward"; comment = "defconf: drop all from WAN not DSTNATed"; connection_nat_state = "!dstnat"; connection_state = "new"; in_interface_list = "WAN"; }
    { name = "input_drop_dns_tcp"; action = "drop"; chain = "input"; dst_port = 53; in_interface_list = "WAN"; protocol = "tcp"; }
    { name = "input_drop_dns_udp"; action = "drop"; chain = "input"; dst_port = 53; in_interface_list = "WAN"; protocol = "udp"; }
  ];

  # Preset default NAT rules
  presetNatRules = [
    { name = "masquerade"; action = "masquerade"; chain = "srcnat"; comment = "defconf: masquerade"; ipsec_policy = "out,none"; out_interface_list = "WAN"; }
    { name = "dns_redirect"; action = "redirect"; chain = "dstnat"; dst_port = 53; protocol = "udp"; to_addresses = config.routeros.connection.gateway; to_ports = 53; }
  ];

  # Combined rules: preset + user
  allFilterRules = presetFilterRules ++ cfg.filterRules;
  allNatRules = presetNatRules ++ cfg.natRules;

  # Build filter rule resources with place_before chaining
  filterRuleCount = builtins.length allFilterRules;
  mkFilterRule = idx:
    let
      rule = builtins.elemAt allFilterRules idx;
      ruleName = rule.name;
      ruleAttrs = builtins.removeAttrs rule [ "name" ];
      withOrdering =
        if idx < filterRuleCount - 1 then
          let nextRule = builtins.elemAt allFilterRules (idx + 1);
          in ruleAttrs // { place_before = "\${routeros_ip_firewall_filter.${nextRule.name}.id}"; }
        else ruleAttrs;
    in { name = ruleName; value = withOrdering; };

  # Build NAT rule resources with place_before chaining
  natRuleCount = builtins.length allNatRules;
  mkNatRule = idx:
    let
      rule = builtins.elemAt allNatRules idx;
      ruleName = rule.name;
      ruleAttrs = builtins.removeAttrs rule [ "name" ];
      withOrdering =
        if idx < natRuleCount - 1 then
          let nextRule = builtins.elemAt allNatRules (idx + 1);
          in ruleAttrs // { place_before = "\${routeros_ip_firewall_nat.${nextRule.name}.id}"; }
        else ruleAttrs;
    in { name = ruleName; value = withOrdering; };
in
{
  options.routeros.firewall = {
    enable = lib.mkEnableOption "firewall";

    connectionTracking = {
      udpTimeout = lib.mkOption {
        type = lib.types.str;
        default = "10s";
        description = "UDP connection tracking timeout.";
      };
    };

    addressLists = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Firewall address lists. Keys are list names, values are lists of addresses.";
      example = { tv = [ "10.0.0.50" "10.0.0.51" ]; };
    };

    filterRules = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Additional firewall filter rules appended after preset rules. Each rule must have a unique 'name' attribute.";
    };

    natRules = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Additional NAT rules appended after preset rules. Each rule must have a unique 'name' attribute.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_ip_firewall_connection_tracking.default = {
        udp_timeout = cfg.connectionTracking.udpTimeout;
      };

      routeros_ip_firewall_addr_list = builtins.listToAttrs (
        lib.concatLists (
          lib.mapAttrsToList (
            listName: addresses:
            lib.imap0 (idx: addr: {
              name = "${helpers.sanitizeName listName}_${toString idx}";
              value = { address = addr; list = listName; };
            }) addresses
          ) cfg.addressLists
        )
      );

      routeros_ip_firewall_filter = builtins.listToAttrs (builtins.genList mkFilterRule filterRuleCount);

      routeros_ip_firewall_nat = builtins.listToAttrs (builtins.genList mkNatRule natRuleCount);
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/firewall.nix
git commit -m "feat: add firewall module (filter rules, NAT, address lists, connection tracking)"
```

---

## Chunk 4: WiFi module, preset, templates, and validation

### Task 11: Create WiFi (CAPsMAN) module

**Files:**
- Create: `~/Projects/Self/nix-routeros/modules/wifi.nix`

- [ ] **Step 1: Create modules/wifi.nix**

```nix
{ config, lib, ... }:
let
  cfg = config.routeros.wifi;
in
{
  options.routeros.wifi = {
    enable = lib.mkEnableOption "WiFi via CAPsMAN";

    ssid = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "WiFi network name (SSID).";
    };

    country = lib.mkOption {
      type = lib.types.str;
      default = "united states";
      description = "Regulatory country for WiFi channels.";
    };

    channels = {
      "2g" = {
        band = lib.mkOption {
          type = lib.types.str;
          default = "2ghz-b/g/n";
          description = "2.4GHz band mode.";
        };
        channelWidth = lib.mkOption {
          type = lib.types.str;
          default = "20mhz";
          description = "2.4GHz control channel width.";
        };
      };
      "5g" = {
        band = lib.mkOption {
          type = lib.types.str;
          default = "5ghz-a/n/ac";
          description = "5GHz band mode.";
        };
        channelWidth = lib.mkOption {
          type = lib.types.str;
          default = "20mhz";
          description = "5GHz control channel width.";
        };
      };
    };

    datapath = {
      clientToClientForwarding = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow client-to-client traffic.";
      };
      localForwarding = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable local forwarding.";
      };
    };

    security = {
      authenticationTypes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "wpa-psk" "wpa2-psk" ];
        description = "Authentication types.";
      };
      encryption = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "aes-ccm" ];
        description = "Encryption methods.";
      };
    };

    provisioning = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [
        { name = "prov_5G"; hw_supported_modes = [ "ac" ]; master_configuration = "5G"; name_prefix = "5G"; }
        { name = "prov_2G"; hw_supported_modes = [ "gn" ]; master_configuration = "2G"; name_prefix = "2G"; }
      ];
      description = "CAPsMAN provisioning rules.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_capsman_channel = {
        channel_2G = {
          name = "2G";
          band = cfg.channels."2g".band;
          control_channel_width = cfg.channels."2g".channelWidth;
        };
        channel_5G = {
          name = "5G";
          band = cfg.channels."5g".band;
          control_channel_width = cfg.channels."5g".channelWidth;
        };
      };

      routeros_capsman_datapath.datapath = {
        name = "datapath";
        bridge = "bridge";
        client_to_client_forwarding = cfg.datapath.clientToClientForwarding;
        local_forwarding = cfg.datapath.localForwarding;
      };

      routeros_capsman_security.security = {
        name = "security";
        authentication_types = cfg.security.authenticationTypes;
        encryption = cfg.security.encryption;
        passphrase = "\${var.wifi_password}";
      };

      routeros_capsman_configuration = let
        chains = [ 0 1 2 3 ];
        mkConfig = name: channelName: {
          inherit name;
          channel.config = channelName;
          country = cfg.country;
          datapath.config = "datapath";
          installation = "any";
          mode = "ap";
          rx_chains = chains;
          security.config = "security";
          ssid = cfg.ssid;
          tx_chains = chains;
        };
      in {
        config_2G = mkConfig "2G" "2G";
        config_5G = mkConfig "5G" "5G";
      };

      routeros_capsman_manager.manager = {
        enabled = true;
        upgrade_policy = "require-same-version";
      };

      routeros_capsman_manager_interface.bridge = {
        disabled = false;
        interface = "bridge";
      };

      routeros_capsman_provisioning = builtins.listToAttrs (
        builtins.map (prov: {
          name = prov.name;
          value = {
            action = "create-dynamic-enabled";
            hw_supported_modes = prov.hw_supported_modes;
            master_configuration = prov.master_configuration;
            name_format = "prefix-identity";
            name_prefix = prov.name_prefix;
          };
        }) cfg.provisioning
      );
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/wifi.nix
git commit -m "feat: add WiFi/CAPsMAN module (channels, security, provisioning, manager)"
```

---

### Task 12: Create router preset

**Files:**
- Create: `~/Projects/Self/nix-routeros/presets/router.nix`

- [ ] **Step 1: Create presets/router.nix**

```nix
{ config, ... }:
{
  imports = [ ../modules ];

  routeros = {
    system = {
      timezone = "UTC";

      services = let subnet = config.routeros.network.subnet; in {
        ssh = { enable = true; allowedAddresses = subnet; };
        winbox = { enable = true; allowedAddresses = subnet; };
        api = { enable = true; allowedAddresses = subnet; };
        ftp.enable = false;
        telnet.enable = false;
        www.enable = false;
        api-ssl.enable = false;
      };

      ipv6.enable = false;
      macServer.enable = true;
      neighborDiscovery.enable = true;
      bfd.enable = true;
    };

    bridge.enable = true;

    network.dhcp = {
      server.enable = true;
      client.enable = true;
    };

    dns = {
      enable = true;
      upstream = [ "8.8.8.8" "4.4.4.4" ];
      localDomain = "local";
    };

    firewall.enable = true;

    wifi.enable = false;
    interfaces.lte.enable = false;
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add presets/
git commit -m "feat: add router preset with opinionated home-router defaults"
```

---

### Task 13: Create template and example

**Files:**
- Create: `~/Projects/Self/nix-routeros/templates/default/flake.nix`
- Create: `~/Projects/Self/nix-routeros/templates/default/router.nix`
- Create: `~/Projects/Self/nix-routeros/examples/basic/flake.nix`
- Create: `~/Projects/Self/nix-routeros/examples/basic/config.nix`

- [ ] **Step 1: Create templates/default/flake.nix**

```nix
{
  description = "My MikroTik router configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-routeros = {
      url = "github:OWNER/nix-routeros";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.terranix.follows = "terranix";
    };
  };

  outputs = { nixpkgs, terranix, nix-routeros, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default = nix-routeros.lib.mkRouterDerivation {
        inherit pkgs system;
        name = "router";
        modules = [ ./router.nix ];
        stateDir = ".";
      };
    };
}
```

- [ ] **Step 2: Create templates/default/router.nix**

```nix
{
  # Required: your network configuration
  routeros = {
    connection = {
      gateway = "10.0.0.1";
      username = "admin";
    };

    network = {
      subnet = "10.0.0.0/24";
      dhcp.server.range = "10.0.0.50-10.0.0.250";
    };

    bridge.ports = [
      "ether2" "ether3" "ether4" "ether5"
    ];

    # Your devices
    hosts = {
      server = {
        ip = "10.0.0.10";
        mac = "AA:BB:CC:DD:EE:FF";
        comment = "Home server";
        aliases = [ "jellyfin" "home-assistant" ];
      };
    };

    # Optional: enable WiFi
    # wifi = {
    #   enable = true;
    #   ssid = "MY-NETWORK";
    #   country = "united states";
    # };
  };
}
```

- [ ] **Step 3: Create examples/basic/flake.nix**

```nix
{
  description = "nix-routeros basic example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-routeros = {
      url = "path:../../";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.terranix.follows = "terranix";
    };
  };

  outputs = { nixpkgs, terranix, nix-routeros, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default = nix-routeros.lib.mkRouterDerivation {
        inherit pkgs system;
        name = "router";
        modules = [ ./config.nix ];
        stateDir = ".";
      };
    };
}
```

- [ ] **Step 4: Create examples/basic/config.nix**

```nix
{
  routeros = {
    connection.gateway = "10.0.0.1";
    network = {
      subnet = "10.0.0.0/24";
      dhcp.server.range = "10.0.0.50-10.0.0.250";
    };
    bridge.ports = [ "ether2" "ether3" "ether4" "ether5" ];
    hosts.server = {
      ip = "10.0.0.10";
      mac = "AA:BB:CC:DD:EE:FF";
      comment = "Server";
    };
  };
}
```

- [ ] **Step 5: Commit**

```bash
git add templates/ examples/
git commit -m "feat: add template and basic example"
```

---

### Task 14: Validate flake evaluates

- [ ] **Step 1: Run nix flake check**

```bash
cd ~/Projects/Self/nix-routeros
nix flake check --no-build
```

Expected: no evaluation errors.

- [ ] **Step 2: Test terranix evaluation via example**

```bash
cd ~/Projects/Self/nix-routeros/examples/basic
nix build .#default 2>&1
```

Expected: builds successfully, produces a `result` symlink.

- [ ] **Step 3: Test show script produces valid JSON**

```bash
cd ~/Projects/Self/nix-routeros/examples/basic
nix run .#default 2>&1 | head -20
```

Verify it produces JSON with `resource.routeros_*` keys.

- [ ] **Step 4: Fix any evaluation errors found, commit fixes**

```bash
git add -A
git commit -m "fix: resolve evaluation errors from flake check"
```

---

## Chunk 5: Migration (nix-config consumer)

### Task 15: Migrate nix-config to consume nix-routeros

This task is done back in the `nix-config` repo.

**Files:**
- Modify: `/Users/oleksandrsy/.nix-config/flake.nix` — add nix-routeros input
- Create: `/Users/oleksandrsy/.nix-config/infra/router/config.nix` — routeros.* config
- Modify: `/Users/oleksandrsy/.nix-config/infra/router/default.nix` — use nix-routeros
- Delete: `/Users/oleksandrsy/.nix-config/infra/router/modules/` — replaced by nix-routeros

- [ ] **Step 1: Add nix-routeros as flake input**

In `flake.nix`, add to inputs:

```nix
nix-routeros = {
  url = "path:../nix-routeros";  # or github:owner/nix-routeros after publishing
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.terranix.follows = "terranix";
};
```

- [ ] **Step 2: Create infra/router/config.nix with routeros.* options**

```nix
{ defaults, hosts, ... }:
{
  imports = [ ];  # preset imported by mkRouterDerivation

  routeros = {
    connection = {
      gateway = defaults.network.gateway;
      username = defaults.user;
    };

    system = {
      timezone = defaults.locale.timeZone;
      services = {
        ssh.allowedAddresses = defaults.network.subnet;
        winbox.allowedAddresses = defaults.network.subnet;
        api.allowedAddresses = defaults.network.subnet;
      };
    };

    network = {
      subnet = defaults.network.subnet;
      dhcp.server.range = defaults.network.dhcpRange;
    };

    bridge = {
      ports = [ "ether2" "ether3" "ether4" "ether5" "ether6" "ether7" "ether8" "ether9" "ether10" "sfp1" ];
      adminMac = hosts.router.bridge.mac;
    };

    dns.upstream = defaults.network.dns.upstream;

    wifi = {
      enable = true;
      ssid = defaults.network.wifi.ssid;
      country = "ukraine";
    };

    interfaces.lte = {
      enable = true;
      apn = "ks";
      provider = "Kyivstar";
    };

    hosts = lib.mapAttrs (_: host: {
      inherit (host) ip mac comment dns;
      dhcp = host.dhcp or true;
      aliases = host.aliases or [ ];
    }) hosts;

    firewall = {
      addressLists = {
        tv = [
          defaults.network.hosts.tv
          defaults.network.hosts.tv-wifi
        ];
      };
      # Device-specific rule migrated from old firewall.nix preset
      filterRules = [
        { name = "forward_drop_tv_external"; action = "drop"; chain = "forward"; comment = "drop TV external traffic"; out_interface_list = "WAN"; src_address_list = "tv"; }
      ];
    };
  };
}
```

- [ ] **Step 3: Update infra/router/default.nix to use nix-routeros**

Replace the current module-based setup with `mkRouterDerivation` from nix-routeros (or keep using `mkTerranixDerivation` with nix-routeros modules). The exact integration depends on how `defaults` is passed — this may require adjusting the `extraArgs` approach.

- [ ] **Step 4: Delete infra/router/modules/**

```bash
git rm -r infra/router/modules/
```

- [ ] **Step 5: Verify the generated config.tf.json matches**

```bash
# Generate with old setup (before deletion) and new setup, diff them
nix run .#router 2>/dev/null | jq > /tmp/old.json
# After migration:
nix run .#router 2>/dev/null | jq > /tmp/new.json
diff /tmp/old.json /tmp/new.json
```

- [ ] **Step 6: Commit migration**

```bash
git add -A
git commit -m "refactor(router): migrate to nix-routeros flake"
```
