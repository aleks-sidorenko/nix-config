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
    mediaRoot = "/data/media";
    downloadPath = category: "${downloadRoot}/${category}";
    mediaPath = category: "${mediaRoot}/${category}";
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
            mediaDir = dirs.mediaRoot;

          };

          radarr = {
            enable = true;
            downloadPath = dirs.downloadPath categories.movies;
            mediaPath = dirs.mediaPath categories.movies;
          };

          minidlna = {
            enable = true;
            directories = [
              "V,${dirs.downloadPath categories.movies}"
              "V,${dirs.downloadPath categories.series}"
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
