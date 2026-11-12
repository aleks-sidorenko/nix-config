{ lib, ... }:
let
  # One filesystem for both roots, so the arrs can hardlink downloads into the
  # libraries instead of copying them.
  root = "/data";
  downloadRoot = "${root}/torrents";
  mediaRoot = "${root}/media";
in
{
  constants.media = {
    group = "media";
    inherit downloadRoot mediaRoot;
    categories =
      lib.mapAttrs
        (_: name: {
          inherit name;
          downloadDir = "${downloadRoot}/${name}";
          mediaDir = "${mediaRoot}/${name}";
        })
        {
          movies = "Movies";
          series = "Series";
          books = "Books";
        };
  };
}
