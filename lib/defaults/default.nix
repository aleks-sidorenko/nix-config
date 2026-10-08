_: rec {

  # Defaults for configuration options
  defaults = {
    # default user name
    user = "alexander";
    locale = {
      locales = [
        "en_US.UTF-8"
        "uk_UA.UTF-8"
        "ru_RU.UTF-8"
      ];
      layouts = [
        "us"
        "ua"
        "ru"
      ];

      timeZone = "Europe/Kyiv";
    };

    # Returns the root path for persistent storage
    persistence = {
      # Returns the root path for persistent storage
      # This is used for opt-in persistence, where directories can be mounted to /persist
      # This path is used to store files that should persist across reboots
      root = "/persist";
    };

    disks = {
      boot = "boot";
      root = "root";
    };

    # Accounts the infra stacks and the modules that talk to them share.
    providers = {
      cloudflare.accountId = "4e18ae7a3707f53f8d7cd82fb8e6abad";
    };

    # Offsite backups: one restic repository per host under this bucket.
    # Shared by infra/storage (creates the bucket) and the restic module
    # (builds the repository URL), so the two can't drift.
    backup = {
      bucket = "backups";
    };

    network = {
      subnet = "10.0.0.0/24";
      gateway = "10.0.0.1";
      dhcpRange = "10.0.0.50-10.0.0.250";
      hosts = {
        router = {
          ip = "10.0.0.1";
          mac = "08:55:31:E9:21:7A";
          # Second NIC and the OpenVPN interface; router-only, stripped before
          # the registry is handed to the router module.
          bridge.mac = "08:55:31:E9:21:73";
          ovpn.mac = "FE:24:A6:AA:80:85";
          comment = "Router";
          dhcp = false;
          dns = true;
          aliases = [ "gateway" ];
        };
        cap1 = {
          ip = "10.0.0.11";
          mac = "DC:2C:6E:18:C7:69";
          comment = "cAP floor 1";
          dns = true;
          aliases = [ ];
        };
        cap2 = {
          ip = "10.0.0.12";
          mac = "DC:2C:6E:18:C0:AB";
          comment = "cAP floor 2";
          dns = true;
          aliases = [ ];
        };
        monitor = {
          ip = "10.0.0.30";
          mac = "00:12:17:DC:98:99";
          comment = "Monitor";
          dns = true;
          aliases = [ ];
        };
        ajax = {
          ip = "10.0.0.31";
          mac = "38:B8:EB:C2:54:53";
          comment = "Ajax";
          dns = true;
          aliases = [ ];
        };
        doorbell = {
          ip = "10.0.0.35";
          mac = "3C:E3:6B:4B:21:94";
          comment = "Doorbell";
          dns = false;
          aliases = [ ];
        };
        server = {
          ip = "10.0.0.40";
          mac = "D8:3A:DD:D7:30:67";
          comment = "Server";
          dns = true;
          # Service names are declared by the modules that own them, not here.
          aliases = [ ];
        };
        tv = {
          ip = "10.0.0.50";
          mac = "0C:CA:FB:0B:47:EE";
          comment = "TV lan";
          dns = true;
          aliases = [ ];
        };
        tv-wifi = {
          ip = "10.0.0.51";
          mac = "04:39:26:B6:FB:6C";
          comment = "TV wifi";
          dns = false;
          aliases = [ ];
        };
        inverter = {
          ip = "10.0.0.52";
          mac = "D4:27:87:27:B8:3E";
          comment = "Deye inverter";
          dns = true;
          aliases = [ ];
        };
        heatpump = {
          ip = "10.0.0.53";
          mac = "EC:FA:BC:C2:EC:C6";
          comment = "Heatpump";
          dns = true;
          aliases = [ ];
        };
        ps5 = {
          ip = "10.0.0.54";
          mac = "68:28:6C:7C:24:E9";
          comment = "PS5";
          dns = false;
          aliases = [ ];
        };
        "1c-key" = {
          ip = "10.0.0.60";
          mac = "08:00:27:98:89:98";
          comment = "1C HASP Licence Manager";
          dns = false;
          aliases = [ ];
        };
        desktop = {
          ip = "10.0.0.61";
          mac = "F4:6D:04:25:80:5F";
          comment = "Desktop";
          # Resolved only through /etc/hosts before; with that rendering gone
          # the .lan name has to come from the router's zone instead.
          dns = true;
          aliases = [ ];
        };
        workbook = {
          ip = "10.0.0.62";
          mac = "A0:CE:C8:C1:23:A1";
          comment = "Work Macbook";
          dns = false;
          aliases = [ ];
        };
        homebook = {
          ip = "10.0.0.63";
          mac = "68:EC:C5:C2:36:1B";
          comment = "Ruslana, Dima, Windows";
          # Resolved only through /etc/hosts before; with that rendering gone
          # the .lan name has to come from the router's zone instead.
          dns = true;
          aliases = [ ];
        };
        server-vm = {
          ip = "10.0.0.64";
          mac = "52:54:00:00:00:64";
          comment = "Home-server stand-in (QEMU guest on the workbook)";
          dns = false;
          dhcp = false;
          aliases = [ ];
        };
        ipad = {
          ip = "10.0.0.70";
          # iOS private/per-network Wi-Fi MAC (randomization left on; stable for this
          # SSID). Hardware MAC is D2:DD:9C:EC:E6:E8 if randomization is ever disabled.
          mac = "0A:99:AE:77:3C:1B";
          comment = "iPad";
          dns = false;
          aliases = [ ];
        };
      };
      domains = {
        lan = "lan";
        public = "sidorenko.me";
        # Services get a real zone rather than a LAN-only name: it resolves the
        # same on and off the LAN, and can hold a certificate.
        services = "home.sidorenko.me";
        # MagicDNS suffix; account-specific.
        tailnet = "colobus-bramble.ts.net";
      };
      dns = {
        upstream = [
          "8.8.8.8"
          "4.4.4.4"
        ];
      };
      wifi = {
        ssid = "SWEET-HOME";
      };
      ports = {
        dlna = {
          web = 8200;
          discovery = 1900;
        };
        jellyfin = {
          web = 8096;
          discovery = 7359;
        };
        qbittorrent = {
          web = 8080;
          torrent = 17348;
        };
        radarr = {
          web = 7878;
        };
        sonarr = {
          web = 8989;
        };
        prowlarr = {
          web = 9696;
        };
        calibre = {
          web = 8083;
        };
        home-assistant = {
          web = 8123;
        };
        restic = {
          web = 8000;
        };
        zigbee2mqtt = {
          web = 8099;
        };
        mqtt = {
          broker = 1883;
        };
        minecraft = {
          server = 25565;
        };
      };
    };
  };

}
