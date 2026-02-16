# 2026-02-15 12:26:14 by RouterOS 7.20.2
# software id = T62P-J94M
#
# model = RB3011UiAS
# serial number = E14E0DAFA533
/caps-man channel
add band=2ghz-b/g/n control-channel-width=20mhz name=2G
add band=5ghz-a/n/ac control-channel-width=20mhz name=5G
/interface bridge
add admin-mac=08:55:31:E9:21:73 auto-mac=no comment=defconf name=bridge \
    port-cost-mode=short
/interface ethernet
set [ find default-name=ether1 ] comment=WAN1
/caps-man datapath
add bridge=bridge client-to-client-forwarding=yes local-forwarding=yes name=\
    datapath
/caps-man security
add authentication-types=wpa-psk,wpa2-psk encryption=aes-ccm name=security \
    passphrase=sp@rt@n!
/caps-man configuration
add channel=2G country=ukraine datapath=datapath installation=any mode=ap \
    name=2G rx-chains=0,1,2,3 security=security ssid=SWEET-HOME tx-chains=\
    0,1,2,3
add channel=5G country=ukraine datapath=datapath installation=any mode=ap \
    name=5G rx-chains=0,1,2,3 security=security ssid=SWEET-HOME tx-chains=\
    0,1,2,3
/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
/interface lte apn
set [ find default=yes ] apn=ks ip-type=ipv4 ipv6-interface=bridge name=\
    Kyivstar use-network-apn=no
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ip pool
add name=dhcp ranges=10.0.0.50-10.0.0.250
/ip dhcp-server
add address-pool=dhcp interface=bridge lease-time=1d name=defconf
/ip smb users
set [ find default=yes ] disabled=yes
/port
set 0 name=serial0
/caps-man manager
set enabled=yes upgrade-policy=require-same-version
/caps-man manager interface
add disabled=no interface=bridge
/caps-man provisioning
add action=create-dynamic-enabled hw-supported-modes=ac master-configuration=\
    5G name-format=prefix-identity name-prefix=5G
add action=create-dynamic-enabled hw-supported-modes=gn master-configuration=\
    2G name-format=prefix-identity name-prefix=2G
/interface bridge port
add bridge=bridge comment=defconf ingress-filtering=no interface=ether2 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether3 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether4 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether5 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether6 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether7 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether8 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether9 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=ether10 \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf ingress-filtering=no interface=sfp1 \
    internal-path-cost=10 path-cost=10
/ip firewall connection tracking
set udp-timeout=10s
/ip neighbor discovery-settings
set discover-interface-list=LAN
/ip settings
set max-neighbor-entries=8192
/ipv6 settings
set accept-router-advertisements=yes disable-ipv6=yes max-neighbor-entries=\
    8192 soft-max-neighbor-entries=8191
/interface list member
add comment=defconf interface=bridge list=LAN
add comment=defconf interface=ether1 list=WAN
add interface=lte1 list=WAN
/interface ovpn-server server
add auth=sha1,md5 mac-address=FE:24:A6:AA:80:85 name=ovpn-server1
/ip address
add address=10.0.0.1/24 comment=defconf interface=bridge network=10.0.0.0
/ip dhcp-client
add comment=defconf interface=ether1
/ip dhcp-server lease
add address=10.0.0.11 client-id=1:dc:2c:6e:18:c7:69 mac-address=\
    DC:2C:6E:18:C7:69 server=defconf
add address=10.0.0.12 client-id=1:dc:2c:6e:18:c0:ab mac-address=\
    DC:2C:6E:18:C0:AB server=defconf
add address=10.0.0.30 client-id=1:0:12:17:dc:98:99 comment=Monitor \
    mac-address=00:12:17:DC:98:99 server=defconf
add address=10.0.0.50 client-id=1:c:ca:fb:b:47:ee comment="tv lan" \
    mac-address=0C:CA:FB:0B:47:EE server=defconf
add address=10.0.0.31 client-id=1:38:b8:eb:c2:54:53 comment=Ajax mac-address=\
    38:B8:EB:C2:54:53 server=defconf
add address=10.0.0.35 comment="Doorbell, doesn't use DHCP" mac-address=\
    3C:E3:6B:4B:21:94 server=defconf
add address=10.0.0.40 client-id=1:d8:3a:dd:d7:30:67 comment=server \
    mac-address=D8:3A:DD:D7:30:67 server=defconf
add address=10.0.0.51 client-id=1:4:39:26:b6:fb:6c comment="tv wifi" \
    mac-address=04:39:26:B6:FB:6C server=defconf
add address=10.0.0.53 comment=heatpump mac-address=EC:FA:BC:C2:EC:C6 server=\
    defconf
add address=10.0.0.52 client-id=1:d4:27:87:27:b8:3e comment=inverter \
    mac-address=D4:27:87:27:B8:3E server=defconf
/ip dhcp-server network
add address=10.0.0.0/24 comment=defconf dns-server=10.0.0.1 gateway=10.0.0.1 \
    netmask=24
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,4.4.4.4
/ip dns static
add forward-to=10.0.0.1 regexp=".*\\.local\$" type=FWD
add address=10.0.0.40 name=server.local type=A
add address=10.0.0.30 name=monitor.local type=A
add address=10.0.0.50 name=tv.local type=A
add address=10.0.0.40 name=radarr.local type=A
add address=10.0.0.40 name=jellyfin.local type=A
add address=10.0.0.40 name=qbittorrent.local type=A
add address=10.0.0.40 name=prowlarr.local type=A
add address=10.0.0.40 name=minidlna.local type=A
add address=10.0.0.40 name=sonarr.local type=A
add address=10.0.0.40 name=home-assistant.local type=A
add address=10.0.0.40 name=zigbee2mqtt.local type=A
add address=10.0.0.40 name=minecraft.local type=A
add address=10.0.0.53 name=heatpump.local type=A
add address=10.0.0.52 name=inverter.local type=A
add address=10.0.0.31 name=ajax.local type=A
add address=10.0.0.40 name=restic.local type=A
/ip firewall address-list
add address=10.0.0.50/31 list=TV
/ip firewall filter
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMP" protocol=icmp
add action=accept chain=input comment=\
    "defconf: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1
add action=drop chain=input comment="defconf: drop all not coming from LAN" \
    in-interface-list=!LAN
add action=accept chain=forward comment="defconf: accept in ipsec policy" \
    ipsec-policy=in,ipsec
add action=accept chain=forward comment="defconf: accept out ipsec policy" \
    ipsec-policy=out,ipsec
add action=fasttrack-connection chain=forward comment="defconf: fasttrack" \
    connection-state=established,related hw-offload=yes
add action=accept chain=forward comment=\
    "defconf: accept established,related, untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop all from WAN not DSTNATed" connection-nat-state=!dstnat \
    connection-state=new in-interface-list=WAN
add action=drop chain=input dst-port=53 in-interface-list=WAN protocol=tcp
add action=drop chain=input dst-port=53 in-interface-list=WAN protocol=udp
add action=drop chain=forward comment="drop TV external traffic" \
    out-interface-list=WAN src-address-list=TV
/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" \
    ipsec-policy=out,none out-interface-list=WAN
add action=redirect chain=dstnat dst-port=53 protocol=udp to-addresses=\
    10.0.0.1 to-ports=53
/ip ipsec profile
set [ find default=yes ] dpd-interval=2m dpd-maximum-failures=5
/ip service
set ftp disabled=yes
set ssh address=10.0.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.0.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/ip smb shares
set [ find default=yes ] directory=/pub
/lcd
set default-screen=log enabled=no touch-screen=disabled
/routing bfd configuration
add disabled=no
/system clock
set time-zone-name=Europe/Kyiv
/system identity
set name=Router
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
