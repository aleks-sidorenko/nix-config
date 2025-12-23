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
    root = "/data";
    downloadRoot = "${root}/torrents";
    mediaRoot = "${root}/media";
    downloadDir = category: "${downloadRoot}/${category}";
    mediaDir = category: "${mediaRoot}/${category}";
  };
in
{
  options.${namespace}.roles.media-server = {
    enable = mkEnableOption "Enable media server role.";
  };

  config = mkIf cfg.enable {

    # Alert if downloadRoot and mediaRoot are not in the same parent directory
    assertions = [
      {
        assertion = (dirOf dirs.downloadRoot) == (dirOf dirs.mediaRoot);
        message = "downloadRoot (${dirs.downloadRoot}) and mediaRoot (${dirs.mediaRoot}) must be in the same parent directory. Currently: downloadRoot parent is '${dirOf dirs.downloadRoot}', mediaRoot parent is '${dirOf dirs.mediaRoot}'.";
      }
    ];

    ${namespace} = {

      services = {

        media = {
          qbittorrent = {
            enable = true;
            categories = categories.all;
            downloadDir = dirs.downloadRoot;
          };

          jellyfin = {
            enable = true;
            mediaDir = dirs.mediaRoot;
          };

          radarr = {
            enable = true;
            downloadDir = dirs.downloadDir categories.movies;
            mediaDir = dirs.mediaDir categories.movies;
          };

          sonarr = {
            enable = true;
            downloadDir = dirs.downloadDir categories.series;
            mediaDir = dirs.mediaDir categories.series;
          };

          prowlarr = {
            enable = true;
          };

          minidlna = {
            enable = true;
            directories = [
              "V,${dirs.mediaDir categories.movies}"
              "V,${dirs.mediaDir categories.series}"
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
