{
  lib,
  namespace,
  ...
}:
with lib.${namespace};
{

  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    user = {
      enable = true;
    };

    roles.graphical = enabled;

    # The guest's stated purpose is media and torrents.
    media.qbittorrent = enabled;
  };

  home.stateVersion = "25.05";
}
