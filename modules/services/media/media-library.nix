{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.media-library).config;
  m = c.nix-config.media;
in
{
  # The layout every media service shares. Features read it from here instead
  # of having it passed in, so no feature depends on a role.
  flake.modules.nixos.media-library =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.nix-config.media;
      fixed =
        type: value: description:
        mkOption {
          inherit type description;
          default = value;
          readOnly = true;
        };
    in
    {
      options.nix-config.media = {
        group = fixed types.str "media" "Group the media services share.";
        root = fixed types.str "/data" "Root of the media layout.";
        downloadRoot = fixed types.str "${cfg.root}/torrents" "Where downloads land.";
        mediaRoot = fixed types.str "${cfg.root}/media" "Where the libraries live.";
        categories = fixed (types.attrsOf types.str) {
          movies = "Movies";
          series = "Series";
          books = "Books";
        } "Media categories, each a directory under both roots.";
        downloadDir = fixed (types.functionTo types.str) (
          category: "${cfg.downloadRoot}/${category}"
        ) "Download directory of a category.";
        mediaDir = fixed (types.functionTo types.str) (
          category: "${cfg.mediaRoot}/${category}"
        ) "Library directory of a category.";
      };

      config = {
        users.groups.${cfg.group} = lib.mkDefault { };

        # Alert if downloadRoot and mediaRoot are not in the same parent directory
        assertions = [
          {
            assertion = (dirOf cfg.downloadRoot) == (dirOf cfg.mediaRoot);
            message = "downloadRoot (${cfg.downloadRoot}) and mediaRoot (${cfg.mediaRoot}) must be in the same parent directory. Currently: downloadRoot parent is '${dirOf cfg.downloadRoot}', mediaRoot parent is '${dirOf cfg.mediaRoot}'";
          }
        ];
      };
    };

  evalTests = {
    media-library-group = {
      expr = c.users.groups ? media;
      expected = true;
    };
    media-library-dirs = {
      expr = [
        (m.downloadDir m.categories.movies)
        (m.mediaDir m.categories.books)
      ];
      expected = [
        "/data/torrents/Movies"
        "/data/media/Books"
      ];
    };
    media-library-assertion = {
      expr = dirOf m.downloadRoot == dirOf m.mediaRoot;
      expected = true;
    };
  };
}
