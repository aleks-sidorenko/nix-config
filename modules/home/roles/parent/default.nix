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

  # `childDevices` are IPs sourced from the single source of truth
  # (defaults.network.hosts.*); router-net accepts raw IPs, so no name→IP
  # resolution is needed here. Dots are escaped for the grep -E status filter.
  childIpRegex = concatStringsSep "|" (
    map (ip: replaceStrings [ "." ] [ "\\." ] ip) cfg.childDevices
  );
  devicesArgs = escapeShellArgs cfg.childDevices;

  # Thin policy wrapper over the generic `router-net` (installed via the
  # router role this role enables). Contains no router logic of its own;
  # it only bakes in the child device list and a display filter for `status`.
  # NOTE: no pkgs.stdenv.isLinux assertion — this runs from the parent's own
  # machine, which may be the darwin workbook (unlike roles.child).
  # SAFETY: prefer running `child-net`/`router-net` from a host that is NOT
  # itself in `childDevices` (e.g. desktop/workbook), so a `block` can't sever
  # the operator's own WAN path. From a blocked host it still works if invoked
  # locally (the router is reachable over LAN, so `unblock` self-heals).
  child-net = pkgs.writeShellApplication {
    name = "child-net";
    runtimeInputs = [ pkgs.gnugrep ]; # router-net is an ambient PATH dep (installed by roles.router)
    text = ''
      case "''${1:-}" in
        block)   exec router-net block ${devicesArgs} ;;
        unblock) exec router-net unblock ${devicesArgs} ;;
        status)
          # Capture first so `set -e` surfaces a real router-net/SSH failure
          # instead of it being swallowed as "nothing blocked" by the grep below.
          status_out="$(router-net status)"
          if printf '%s\n' "$status_out" | grep -E '${childIpRegex}'; then
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
      defaults.network.hosts.tv
      defaults.network.hosts.tv-wifi
      defaults.network.hosts.ps5
      defaults.network.hosts.homebook
      defaults.network.hosts.ipad
    ] "Child's device IPs (from defaults.network.hosts) the parent can cut off";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = all (ip: elem ip (attrValues defaults.network.hosts)) cfg.childDevices;
        message =
          "roles.parent.childDevices contains unknown IP(s): "
          + concatStringsSep ", " (filter (ip: !elem ip (attrValues defaults.network.hosts)) cfg.childDevices)
          + ". Valid host IPs: "
          + concatStringsSep ", " (attrValues defaults.network.hosts);
      }
    ];

    # Generic router control primitive (`router-net`) lives here.
    ${namespace}.roles.router = enabled;

    home.packages = [ child-net ];
  };
}
