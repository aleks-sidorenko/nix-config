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
  };
}
