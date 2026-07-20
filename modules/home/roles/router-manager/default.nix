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
  cfg = config.${namespace}.roles.router-manager;

  # name→IP resolution baked from the single source of truth (lib/defaults).
  hostCases = concatStringsSep "\n    " (
    mapAttrsToList (name: ip: "${name}) echo ${ip} ;;") defaults.network.hosts
  );
  knownNames = concatStringsSep " " (attrNames defaults.network.hosts);

  # Generic, host-agnostic router control. Knows nothing about child/parent.
  # Mutates the terranix-declared `banned` address-list (the one fed to the
  # always-on forward_drop_banned_external rule). SSH transport is overridable
  # via ROUTER_SSH (a single command taking the RouterOS script as one arg) for
  # testing; default is `ssh router` (same alias router-backup uses).
  router-net = pkgs.writeShellApplication {
    name = "router-net";
    runtimeInputs = [ pkgs.openssh ];
    # SC2029: the default `ssh router "$1"` fallback intentionally passes the
    # whole pre-built RouterOS script as a single client-side-expanded
    # argument — there is no remote-side variable to (mis)quote here.
    excludeShellChecks = [ "SC2029" ];
    text = ''
      usage() {
        cat >&2 <<'EOF'
      usage:
        router-net block   <host|ip>...   add hosts to the router `banned` list (+ drop live connections)
        router-net unblock <host|ip>...   remove hosts from the `banned` list
        router-net status                 print current `banned` members
      EOF
        exit 2
      }

      resolve() {
        case "$1" in
          ${hostCases}
          *)
            if [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
              echo "$1"
            else
              echo "router-net: unknown host '$1'. Known: ${knownNames}" >&2
              return 1
            fi
            ;;
        esac
      }

      run_on_router() {
        # $1 = RouterOS command script (possibly multi-line)
        if [[ -n "''${ROUTER_SSH:-}" ]]; then
          "''${ROUTER_SSH}" "$1"
        else
          ssh router "$1"
        fi
      }

      cmd="''${1:-}"; shift || true
      case "$cmd" in
        block)
          [[ $# -ge 1 ]] || usage
          script=""
          for h in "$@"; do
            ip="$(resolve "$h")" || exit 1
            esc="''${ip//./\\.}"
            script+="/ip firewall address-list remove [find where list=banned address=$ip]"$'\n'
            script+="/ip firewall address-list add list=banned address=$ip comment=router-net"$'\n'
            script+="/ip firewall connection remove [find where src-address~\"^$esc:\"]"$'\n'
          done
          run_on_router "$script"
          echo "blocked: $*"
          ;;
        unblock)
          [[ $# -ge 1 ]] || usage
          script=""
          for h in "$@"; do
            ip="$(resolve "$h")" || exit 1
            script+="/ip firewall address-list remove [find where list=banned address=$ip]"$'\n'
          done
          run_on_router "$script"
          echo "unblocked: $*"
          ;;
        status)
          run_on_router '/ip firewall address-list print where list=banned'
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  options.${namespace}.roles.router-manager = {
    enable = mkEnableOption "Enable router manager configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.winbox4
      router-net
    ];
  };
}
