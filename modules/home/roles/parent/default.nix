{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.parent;

  # Resolve the child device names to IPs (for the focused status filter) from
  # the single source of truth. `childDevices` are validated below.
  childIps = map (name: defaults.network.hosts.${name}) cfg.childDevices;
  childIpRegex = concatStringsSep "|" (map (ip: replaceStrings [ "." ] [ "\\." ] ip) childIps);
  devicesArgs = escapeShellArgs cfg.childDevices;

  # Thin policy wrapper over the generic `router-net` (installed via the
  # router-manager role this role enables). Contains no router logic of its own;
  # it only bakes in the child device list and a display filter for `status`.
  # NOTE: no pkgs.stdenv.isLinux assertion — this runs from the parent's own
  # machine, which may be the darwin workbook (unlike roles.child).
  child-net = pkgs.writeShellApplication {
    name = "child-net";
    runtimeInputs = [ pkgs.gnugrep ]; # router-net is an ambient PATH dep (installed by roles.router-manager)
    text = ''
      case "''${1:-}" in
        block)   exec router-net block ${devicesArgs} ;;
        unblock) exec router-net unblock ${devicesArgs} ;;
        status)
          if router-net status | grep -E '${childIpRegex}'; then
            :
          else
            echo "(no child devices currently blocked)"
          fi
          ;;
        *)
          echo "usage: child-net block|unblock|status" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  options.${namespace}.roles.parent = {
    enable = mkEnableOption "Enable the parent role (control the child's devices' internet)";
    childDevices = mkOpt (types.listOf types.str) [
      "tv"
      "tv-wifi"
      "homebook"
      "ipad"
    ] "Child's device host names (keys into defaults.network.hosts) the parent can cut off";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = all (d: hasAttr d defaults.network.hosts) cfg.childDevices;
        message =
          "roles.parent.childDevices contains unknown host(s): "
          + concatStringsSep ", " (filter (d: !hasAttr d defaults.network.hosts) cfg.childDevices)
          + ". Valid hosts: "
          + concatStringsSep ", " (attrNames defaults.network.hosts);
      }
    ];

    # Generic router control primitive (`router-net`) lives here.
    ${namespace}.roles.router-manager = enabled;

    home.packages = [ child-net ];
  };
}
