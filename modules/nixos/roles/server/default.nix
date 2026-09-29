{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.server;
in
{
  options.${namespace}.roles.server = {
    enable = mkEnableOption "Enable server role";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      roles = {
        common = enabled;
      };

      system = {
        locale = {
          locales = lib.mkForce [ "en_US.UTF-8" ];
          layouts = lib.mkForce [ "us" ];
          timeZone = lib.mkForce "UTC";
        };
      };

      services.networking.nginx = enabled;

      services.networking.tailscale.tags = [ "tag:server" ];

    };

    # A server's ingress is nginx and SSH; everything else is closed by
    # default. Set here rather than per host so a new server inherits it.
    # Plain assignment (not mkDefault) because system/networking's own
    # `enable = false` needs to be the one left overridable — see the
    # mkDefault there.
    networking.firewall.enable = true;

    environment = {
      systemPackages = [
        pkgs.nfs-utils
        pkgs.openiscsi
        pkgs.dnsutils
      ];
      # Print the URL instead on servers
      variables.BROWSER = "echo";
    }
    // optionalAttrs (versionAtLeast (versions.majorMinor version) "24.05") {
      # Don't install the /lib/ld-linux.so.2 and /lib64/ld-linux-x86-64.so.2
      # stubs. Server users should know what they are doing.
      stub-ld.enable = mkDefault false;
    };

    security = {
      sudo = {
        # Don't require a password for the wheel group
        wheelNeedsPassword = false;
        # Only allow members of the wheel group to execute sudo by setting the executable’s permissions accordingly. This prevents users that are not members of wheel from exploiting vulnerabilities in sudo such as CVE-2021-3156.
        execWheelOnly = true;
        # Don't lecture the user. Less mutable state.
        extraConfig = ''
          Defaults lecture = never
        '';
      };
    };

    # Notice this also disables --help for some commands such es nixos-rebuild
    documentation = {
      enable = mkDefault false;
      info.enable = mkDefault false;
      man.enable = mkDefault false;
      nixos.enable = mkDefault false;
    };

    systemd = {
      services.NetworkManager-wait-online.enable = false;
      network.wait-online.enable = false;
      tmpfiles.rules = [
        "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
      ];

      # Given that our systems are headless, emergency mode is useless.
      # We prefer the system to attempt to continue booting so
      # that we can hopefully still access it remotely.
      enableEmergencyMode = false;

      settings = {
        # systemd pings the hardware watchdog at half this interval, so every
        # 10s. If the hardware sees no ping for 20s it forcefully reboots.
        # For more detail, see:
        #   https://0pointer.de/blog/projects/watchdog.html
        Manager.RuntimeWatchdogSec = "20s";

        # Forcefully reboot if the final stage of the reboot hangs without
        # progress for more than 30s. This is a separate watchdog from the
        # runtime one above; both were previously written to RuntimeWatchdogSec,
        # so the runtime value was overridden and this one never applied.
        # For more info, see:
        #   https://utcc.utoronto.ca/~cks/space/blog/linux/SystemdShutdownWatchdog
        Manager.RebootWatchdogSec = "30s";
      };
    };

  };
}
