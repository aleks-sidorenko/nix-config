# Layout the media aspects agree on. Downloads and media share a parent so
# the *arr apps can hardlink instead of copying.
root: rec {
  categories = {
    movies = "Movies";
    series = "Series";
    books = "Books";
  };
  downloadRoot = "${root}/torrents";
  mediaRoot = "${root}/media";
  downloadDir = category: "${downloadRoot}/${category}";
  mediaDir = category: "${mediaRoot}/${category}";
  group = "media";
}
