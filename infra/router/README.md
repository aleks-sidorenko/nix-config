# Router Management

## DHCP Leases

```bash
ssh router /ip dhcp-server lease print
```

## Banned Address List

Hosts in the `banned` list are blocked from external (WAN) traffic.

**Permanent:** Add the host to `addressLists.banned` in `default.nix` and apply with terraform.

**Temporary (until next terraform apply):** Use CLI commands below.

Add a host to the banned list (by IP):

```bash
# Find the IP from leases first, then add it
ssh router /ip firewall address-list add list=banned address=<IP>
```

Or as a one-liner — find by MAC and ban:

```bash
ssh router /ip firewall address-list add list=banned address=[/ip dhcp-server lease get [find mac-address=AA:BB:CC:DD:EE:FF] address]
```

Remove from banned:

```bash
ssh router /ip firewall address-list remove [find list=banned address=<IP>]
```

View current banned list:

```bash
ssh router /ip firewall address-list print where list=banned
```
