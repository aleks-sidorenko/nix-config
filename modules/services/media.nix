{ lib, ... }:
{
  # Included by every aspect that reads or writes the media trees.
  den.aspects.services.media = {
    settings.root = lib.mkOption {
      type = lib.types.str;
      default = "/data";
      description = "Directory holding the download and media trees.";
    };

    nixos =
      { host, ... }:
      {
        users.groups.${(import ./_media.nix host).group} = { };
      };
  };
}
