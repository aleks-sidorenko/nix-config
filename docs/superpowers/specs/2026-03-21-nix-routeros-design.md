# nix-routeros Design Spec

## Summary

An open-source Nix flake that provides a NixOS-module-style interface for configuring MikroTik RouterOS routers via terranix (Nix -> Terraform JSON -> OpenTofu -> RouterOS API). Targets home lab / home network users with a single MikroTik router.

Extracted from the `infra/router/` directory of the `nix-config` personal configuration repo.

## Decisions

- **Name**: `nix-routeros`
- **Audience**: Home lab / home network users with a single MikroTik router
- **Engine**: terranix + OpenTofu with the `terraform-routeros/routeros` provider
- **API style**: NixOS-module-style options (`lib.mkOption`, `lib.mkEnableOption`) — full module system with type checking, `mkDefault`/`mkForce` priority, and self-documenting options
- **Layering**: Building-block modules at the core, with an opinionated `presets.router` on top
- **Scope**: Full feature parity with the current setup (bridge, CAPsMAN, DHCP, DNS, firewall, interfaces, LTE, system)
- **Repo relationship**: Separate repo/flake; `nix-config` becomes the first consumer via flake input

## Flake Outputs

```
outputs:
  - terranixModules.default    — imports all feature modules
  - terranixModules.<module>   — individual modules (bridge, dhcp, dns, etc.)
  - presets.router             — opinionated home router defaults
  - lib                        — helper functions (host sanitization, firewall ordering, mkRouterDerivation)
  - templates.default          — flake template for `nix flake init`
```

### Consumer Usage

```nix
{
  inputs.nix-routeros.url = "github:<owner>/nix-routeros";

  # In their router config:
  imports = [
    nix-routeros.terranixModules.default
    nix-routeros.presets.router
  ];

  routeros = {
    connection = { gateway = "10.0.0.1"; username = "admin"; };
    network = { subnet = "10.0.0.0/24"; dhcp.range = "10.0.0.50-10.0.0.250"; };
    hosts.server = { ip = "10.0.0.40"; mac = "AA:BB:CC:DD:EE:FF"; dns = true; };
    wifi.ssid = "MY-NETWORK";
  };
}
```

## Option Tree

```
routeros
├── connection
│   ├── gateway        : str ("10.0.0.1")
│   ├── username       : str ("admin")
│   └── provider       : attrset (version pinning, API scheme)
│
├── system
│   ├── identity       : str (hostname)
│   ├── timezone       : str ("UTC")
│   ├── services       : { ssh, winbox, api, ftp, telnet, www, api-ssl } with enable + allowed-addresses
│   ├── ipSettings     : { maxNeighborEntries : int (8192) }
│   ├── ipv6           : { enable : bool (false), acceptRouterAdvertisements : bool }
│   ├── macServer      : { enable : bool, allowedInterfaces : listOf str }
│   ├── ipsec          : { dpdInterval, dpdMaxFailures }
│   └── neighborDiscovery.enable : bool
│
├── network
│   ├── subnet         : str ("10.0.0.0/24") — gateway/prefix derived automatically
│   ├── dhcp
│   │   ├── server
│   │   │   ├── enable     : bool
│   │   │   ├── range      : str
│   │   │   └── leaseTime  : str ("1d")
│   │   └── client
│   │       ├── enable     : bool (true)
│   │       └── interface  : str — WAN interface for upstream DHCP (defaults to first wan interface)
│
├── hosts              : attrsOf { ip, mac, comment?, dhcp?, dns?, aliases? }
│
├── bridge
│   ├── enable         : bool
│   ├── ports          : listOf str (["ether2" ... "ether10" "sfp1"])
│   └── adminMac       : nullOr str
│
├── dns
│   ├── enable         : bool
│   ├── upstream       : listOf str
│   ├── localDomain    : str ("local")
│   └── aliases        : attrsOf str (name -> target host)
│
├── firewall
│   ├── enable         : bool
│   ├── connectionTracking : { udpTimeout : str, etc. }
│   ├── addressLists   : attrsOf (listOf str)
│   ├── filterRules    : listOf attrset (ordered, appended after preset rules)
│   └── natRules       : listOf attrset (ordered, appended after preset rules)
│
├── wifi
│   ├── enable         : bool
│   ├── ssid           : str
│   ├── country        : str
│   ├── channels       : { 2g, 5g } with band/width settings
│   └── provisioning   : listOf attrset
│
└── interfaces
    ├── wan            : listOf str (["ether1"])
    ├── lte
    │   ├── enable     : bool (false)
    │   ├── apn        : str
    │   └── provider   : str
    └── lists          : attrsOf (listOf str)
```

### Key Design Decisions

- `hosts` is the central source of truth — DHCP leases, DNS A records, and aliases are all derived from it
- `firewall.filterRules` / `natRules` are ordered lists — the module handles `place_before` chaining internally
- `presets.router` fills in sensible defaults for all options (minus hardware-specific values like MACs and bridge ports)
- Hardware-specific options (bridge ports, adminMac, host MACs) have no preset defaults — users must provide them
- LTE is consolidated under `interfaces.lte` (not a separate top-level option) since it's fundamentally an interface type

### Firewall Rule Ordering

The preset defines a base set of filter and NAT rules. User-provided `filterRules` and `natRules` are **appended after** the preset rules. The module concatenates `presetRules ++ userRules` and generates `place_before` references by iterating the combined list.

Users who need to **replace** the preset rules entirely can use `lib.mkForce` on `firewall.filterRules`. Users who need to insert rules at specific positions should override the full list.

### Resource Naming Convention

All terranix resource names are derived deterministically from option values (host names, interface names, etc.) using a unified sanitization function:

- Replace `-` and `.` with `_`
- Prepend `_` for names starting with a digit
- Pattern: `<resource_type>.<descriptive_name>` (e.g., `routeros_ip_dns_record.server`, `routeros_ip_dhcp_server_lease.cap1`)

Consumers writing `imports.nix` blocks need to match these names. The README will document the naming convention and provide an example `imports.nix`.

### DNS Escaping

The `dns.localDomain` option handles RouterOS regex escaping internally. Users provide plain domain names (e.g., `"local"`); the module generates the correct escaped regexp for the FWD record.

## Preset: `presets.router`

Provides a working secured router with DHCP, DNS, firewall, and bridge out of the box:

```nix
{
  routeros = {
    system = {
      timezone = "UTC";
      services = {
        ssh = { enable = true; allowedAddresses = ["LAN subnet"]; };
        winbox = { enable = true; allowedAddresses = ["LAN subnet"]; };
        api = { enable = true; allowedAddresses = ["LAN subnet"]; };
        # Disabled by default (security hardening):
        ftp.enable = false;
        telnet.enable = false;
        www.enable = false;
        api-ssl.enable = false;
      };
      ipv6.enable = false;
      macServer = { enable = true; allowedInterfaces = ["LAN"]; };
      neighborDiscovery.enable = true;
    };
    bridge.enable = true;
    network.dhcp.server = { enable = true; leaseTime = "1d"; };
    network.dhcp.client = { enable = true; }; # DHCP client on WAN for upstream
    dns = { enable = true; upstream = ["8.8.8.8" "4.4.4.4"]; localDomain = "local"; };
    firewall = {
      enable = true;
      connectionTracking = { udpTimeout = "10"; };
      # Default filter rules: accept established/related/untracked, drop invalid,
      # accept ICMP, accept loopback, drop non-LAN input, drop DNS from WAN,
      # accept IPsec in/out, fasttrack, accept established forward,
      # drop invalid forward, drop WAN without DSTNAT
      # Default NAT: masquerade on WAN, DNS redirect to router
    };
    wifi.enable = false;           # Opt-in
    interfaces.lte.enable = false; # Opt-in
  };
}
```

**Users must provide**: `connection.gateway`, `connection.username`, `network.subnet`, `network.dhcp.server.range`, `hosts`, `bridge.ports`, `wifi.ssid` (if wifi enabled).

**Preset also imports**: `presets.router` imports `terranixModules.default`, so consumers only need to import the preset (not both).

## Terranix Integration

The nix-routeros modules **are terranix modules directly** — they produce `resource.*`, `variable.*`, and `terraform.*` attrsets that terranix merges natively. There is no separate `evalModules` step; the consumer passes nix-routeros modules directly to `terranix.lib.terranixConfiguration`:

```nix
# Consumer's flake.nix
let
  tfConfig = terranix.lib.terranixConfiguration {
    system = "x86_64-linux";
    modules = [
      nix-routeros.terranixModules.default
      nix-routeros.presets.router
      ./my-router.nix   # User's routeros.* overrides
    ];
  };
in { /* plan, apply, destroy scripts */ }
```

This matches how the current `infra/router/` works — terranix already uses the NixOS module system internally, so nix-routeros modules define `options.routeros.*` and produce `config.resource.*` within that same evaluation. No two-layer architecture needed.

### What nix-routeros does NOT own

- Wrapper scripts for plan/apply/destroy — consumer brings their own, or uses `lib.mkRouterDerivation`
- Secrets management (SOPS, age) — consumer's responsibility
- State encryption — consumer's `encryption.tf`
- `imports.nix` — device-specific resource ID mappings, lives in consumer's repo

### What nix-routeros provides as optional lib

- `lib.mkRouterDerivation` — convenience function that wraps `terranix.lib.terranixConfiguration` and produces a derivation with `show`, `plan`, `apply`, `destroy` scripts. This is a router-specific helper independent of the consumer's existing tooling (e.g., `nix-config`'s generic `mkTerranixDerivation`). Consumers can use either approach.

## Out of Scope

- **OVPN server** — RouterOS API mode does not support OVPN configuration; must be managed manually
- **LCD / serial port / SMB** — no provider resources available
- **Dynamic DNS / BGP / OSPF** — not needed for home router preset; can be added as future modules
- **Backup script** — stays in consumer repos (hardware/network-specific SSH access). May be added as a lib helper in a future release.

## Repository Layout

```
nix-routeros/
├── flake.nix
├── flake.lock
├── README.md
├── LICENSE
│
├── modules/
│   ├── default.nix              # Imports all modules
│   ├── connection.nix           # Provider config + connection options
│   ├── system.nix               # Identity, clock, services, neighbor discovery
│   ├── bridge.nix               # Bridge interface + ports
│   ├── interfaces.nix           # WAN interfaces, interface lists
│   ├── lte.nix                  # LTE modem + APN
│   ├── dhcp.nix                 # DHCP server, pool, leases (from hosts)
│   ├── dns.nix                  # DNS records, aliases, forwarding (from hosts)
│   ├── firewall.nix             # Filter rules, NAT, address lists
│   └── wifi.nix                 # CAPsMAN channels, security, provisioning
│
├── presets/
│   └── router.nix               # Opinionated home router defaults
│
├── lib/
│   ├── helpers.nix              # Name sanitization, subnet math, firewall ordering
│   └── types.nix                # Custom option types (host, firewall rule, etc.)
│
├── templates/
│   └── default/
│       ├── flake.nix            # Starter flake for `nix flake init`
│       └── router.nix           # Example config with comments
│
└── examples/
    └── basic/
        ├── flake.nix
        └── config.nix
```

## Migration Path for nix-config

1. Add `nix-routeros` as a flake input
2. Replace `infra/router/modules/` with a single `infra/router/config.nix` importing the package modules + preset with hardware-specific values
3. Keep in nix-config: `hosts.nix`, `imports.nix`, `secrets.yaml`, `encryption.tf`, `default.nix` (updated to use `lib.mkRouterDerivation`)
4. Delete: `infra/router/modules/` (now lives in `nix-routeros`)

The nix-config becomes the first consumer — dogfooding from day one.
