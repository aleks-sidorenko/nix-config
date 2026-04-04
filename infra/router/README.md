# Router Management

## DHCP Leases

```bash
ssh router /ip dhcp-server lease print
```

## Banned Address List

Add a MAC to the banned address list (you need the IP, not MAC directly):

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
