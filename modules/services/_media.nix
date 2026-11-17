# Layout the media aspects agree on. Downloads and media share a parent so
# the *arr apps can hardlink instead of copying.
host:
let
  inherit (host.settings.services.media) root;
in
rec {
  categories = {
    movies = "Movies";
    series = "Series";
    books = "Books";
  };
  downloadRoot = "${root}/torrents";
  libraryRoot = "${root}/media";
  downloadDir = category: "${downloadRoot}/${category}";
  mediaDir = category: "${libraryRoot}/${category}";
  group = "media";
}
