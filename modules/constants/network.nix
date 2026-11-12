{
  constants.network = {
    domains = {
      lan = "lan";
      tailnet = "colobus-bramble.ts.net";
      services = "home.sidorenko.me";
    };
    ports = {
      dlna = {
        web = 8200;
        discovery = 1900;
      };
      jellyfin.web = 8096;
      qbittorrent = {
        web = 8080;
        torrent = 17348;
      };
      radarr.web = 7878;
      sonarr.web = 8989;
      prowlarr.web = 9696;
      calibre.web = 8083;
    };
  };
}
