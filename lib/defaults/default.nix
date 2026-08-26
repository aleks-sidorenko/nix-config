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

    network = {
      subnet = "10.0.0.0/24";
      gateway = "10.0.0.1";
      dhcpRange = "10.0.0.50-10.0.0.250";
      hosts = {
        router = "10.0.0.1";
        cap1 = "10.0.0.11";
        cap2 = "10.0.0.12";
        monitor = "10.0.0.30";
        ajax = "10.0.0.31";
        doorbell = "10.0.0.35";
        server = "10.0.0.40";
        tv = "10.0.0.50";
        tv-wifi = "10.0.0.51";
        inverter = "10.0.0.52";
        heatpump = "10.0.0.53";
        ps5 = "10.0.0.54";
        "1c-key" = "10.0.0.60";
        desktop = "10.0.0.61";
        workbook = "10.0.0.62";
        homebook = "10.0.0.63";
        vm = "10.0.0.64";
        ipad = "10.0.0.70";
      };
      domains = {
        local = "local";
        public = "sidorenko.me";
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
