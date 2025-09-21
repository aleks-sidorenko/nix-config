{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.media-server;

  categories = rec {
    movies = "Movies";
    series = "Series";
    audio = "Audio";
    books = "Books";
    software = "Software";
    all = [
      movies
      series
      audio
      books
      software
    ];
  };

  dirs = rec {
    downloadRoot = "/data/torrents";
    media = "/data/media";

    dowloadPath = category: "${dirs.downloadRoot}/${category}";
    mediaPath = category: "${dirs.media}/${category}";
  };
in
{
  options.${namespace}.roles.media-server = {
    enable = mkEnableOption "Enable media server role.";
  };

  config = mkIf cfg.enable {

    ${namespace} = {

      services = {

        media = {
          qbittorrent = {
            enable = true;
            categories = categories.all;
            downloadPath = dirs.downloadRoot;
          };

          jellyfin = {
            enable = false;
            mediaDir = dirs.media;

          };

          radarr = {
            enable = true;
            downloadDir = dirs.dowloadPath categories.movies;
            mediaDir = dirs.mediaPath categories.movies;
          };

          sonarr = {
            enable = false;
            downloadDir = dirs.dowloadPath categories.series;
            mediaDir = dirs.mediaPath categories.series;

          };

          minidlna = {
            enable = true;
            directories = [
              "V,${dirs.dowloadPath categories.movies}"
              "V,${dirs.dowloadPath categories.series}"
            ];
          };
        };
      };

    };

    boot.kernel.sysctl = {

      # Default is usually 8192, increase to handle large media libraries
      "fs.inotify.max_user_watches" = 524288;
      # Also increase max instances if needed
      "fs.inotify.max_user_instances" = 256;
    };

  };
}
