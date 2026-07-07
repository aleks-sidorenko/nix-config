{
  pkgs,
  lib,
  ...
}:
let
  wallpapers = {
    green-plains-on-mountain = pkgs.fetchurl {
      name = "green-plains-on-mountain.jpg";
      url = "https://images.unsplash.com/photo-1547285629-6cab32b3dfdb?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=med-nadjib-ramdane-yg9fwePu9Og-unsplash.jpg&w=1920";
      hash = "sha256-JHbmgI3HtDAek6MCLs9j6P4ATsgHt4JWJTD6Qhi0jbk=";
    };

    the-sun-shines-through-the-fog-in-the-mountains = pkgs.fetchurl {
      name = "the-sun-shines-through-the-fog-in-the-mountains.jpg";
      url = "https://images.unsplash.com/photo-1654169761064-95b4c1e2be6e?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=rob-bates-4He7i9d-Uyw-unsplash.jpg&w=1920";
      hash = "sha256-OBigjxIJ6ixKzYZ+xfpLRRlj34qU+mu6JdYGcZEC+Fg=";
    };

    sun-light-passing-through-green-leafed-tree = pkgs.fetchurl {
      name = "sun-light-passing-through-green-leafed-tree.jpg";
      url = "https://images.unsplash.com/photo-1518495973542-4542c06a5843?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=jeremy-bishop-EwKXn5CapA4-unsplash.jpg&w=1920";
      hash = "sha256-vdYzU6hWCaYBC6bBjVj4jghAwUByfEjXGRLAE+cj/Xs=";
    };
  };
in
pkgs.symlinkJoin {
  name = "wallpapers";
  paths = lib.attrValues wallpapers;
  passthru = wallpapers // {
    names = lib.attrNames wallpapers;
  };
}
