{ den, ... }:
let
  secret = "system-wifi-password";
in
{
  den.aspects.system.wifi = {
    includes = [ den.aspects.system.networkmanager ];

    nixos =
      { config, host, ... }:
      let
        inherit (host.settings.system.networking.wifi) ssid;
      in
      {
        sops.secrets.${secret} = { };
        sops.templates."wifi.env".content = "WIFI_PSK=${config.sops.placeholder.${secret}}";

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ config.sops.templates."wifi.env".path ];
          profiles.home-wifi = {
            connection = {
              id = ssid;
              type = "wifi";
              autoconnect = true;
              # Wins over profiles made by hand on the host.
              autoconnect-priority = 10;
            };
            wifi = {
              mode = "infrastructure";
              inherit ssid;
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = "$WIFI_PSK";
            };
            ipv4.method = "auto";
          };
        };
      };
  };
}
