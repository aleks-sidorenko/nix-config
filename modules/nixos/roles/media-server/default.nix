{
  lib,
  config,
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
    books = "Books";
    all = [
      movies
      series
    ];
  };

  # Media categories whose library should be included in restic backups. Books
  # are small and hand-curated, so they are backed up; Movies/Series are large
  # and re-downloadable, so they are not. Extend this list to back up more.
  backedUp = [
    categories.books
  ];

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
    enable = mkEnableOption "Enable media server role";
  };

  config = mkIf cfg.enable {

    # Alert if downloadRoot and mediaRoot are not in the same parent directory
    assertions = [
      {
        assertion = (dirOf dirs.downloadRoot) == (dirOf dirs.mediaRoot);
        message = "downloadRoot (${dirs.downloadRoot}) and mediaRoot (${dirs.mediaRoot}) must be in the same parent directory. Currently: downloadRoot parent is '${dirOf dirs.downloadRoot}', mediaRoot parent is '${dirOf dirs.mediaRoot}'";
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

          calibre = {
            enable = true;
            libraryDir = dirs.mediaDir categories.books;
          };
        };

        # Back up the selected media libraries (see `backedUp` above).
        backup.restic.extraPaths = map dirs.mediaDir backedUp;

      };

    };

  };
}
