{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options = {
    owner = mkOption {
      type = types.str;
      description = "Name of the person who owns these machines; their identity is authorized where no other user's is.";
    };

    locale = {
      locales = mkOption {
        type = types.listOf types.str;
        description = "Supported locales. The first is the system locale, the second the native one for LC_* settings.";
      };
      layouts = mkOption {
        type = types.listOf types.str;
        description = "Keyboard layouts. The first is the default.";
      };
      timeZone = mkOption {
        type = types.str;
        description = "Owner's home time zone (IANA name).";
      };
    };

    persistence.root = mkOption {
      type = types.str;
      description = "Where impermanent hosts keep the state that survives a reboot.";
    };

    network.domains = {
      lan = mkOption {
        type = types.str;
        description = "LAN search domain.";
      };
      tailnet = mkOption {
        type = types.str;
        description = "Tailnet DNS suffix.";
      };
      services = mkOption {
        type = types.str;
        description = "Domain the hosts' web services are published under.";
      };
    };

    network.ports = mkOption {
      type = types.attrsOf (types.attrsOf types.port);
      description = "Ports the services listen on, by service and purpose (`web`, `torrent`, …).";
    };

    media = {
      group = mkOption {
        type = types.str;
        description = "Group the media services share.";
      };
      downloadRoot = mkOption {
        type = types.str;
        description = "Where downloads land.";
      };
      mediaRoot = mkOption {
        type = types.str;
        description = "Where the libraries live.";
      };
      categories = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Directory name of the category under both roots.";
              };
              downloadDir = mkOption {
                type = types.str;
                description = "Where the category's downloads land.";
              };
              mediaDir = mkOption {
                type = types.str;
                description = "Where the category's library lives.";
              };
            };
          }
        );
        description = "Media categories, each a directory under both roots.";
      };
    };
  };
}
