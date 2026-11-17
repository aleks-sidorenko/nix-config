{
  den.aspects.system.networking = {
    # The DHCP client's leases and identity are re-acquired on every boot.
    persist.ignore = [ "/var/lib/dhcpcd" ];

    nixos.networking.firewall.enable = true;
  };
}
