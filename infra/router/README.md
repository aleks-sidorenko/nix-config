# Router Management

## DHCP Leases

```bash
ssh router /ip dhcp-server lease print
```

## Banned Address List

Hosts in the `banned` list are blocked from external (WAN) traffic.

**Declared baseline:** `addressLists.banned` in `default.nix` is empty — nobody
is blocked by default. Runtime membership is managed on demand by the
`router-net` / `child-net` commands (see `modules/home/roles/router-manager`
and `modules/home/roles/parent`), which add/remove hosts from the `banned`
list over SSH without touching terraform state.

Running `just router-apply` re-applies the declared (empty) baseline, which
clears any active runtime block and brings everyone back online. Only add a
host to `addressLists.banned` in `default.nix` if you want it blocked
permanently, independent of the runtime tools.

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
