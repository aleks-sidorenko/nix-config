{ config, ... }:
{
  flake.modules.nixos.system-server =
    { lib, pkgs, ... }:
    {
      imports = with config.flake.modules.nixos; [
        system-common
        nginx
      ];

      nix-config = {
        locale = {
          locales = [ "en_US.UTF-8" ];
          layouts = [ "us" ];
          timeZone = "UTC";
        };
        tailscale.tags = [ "tag:server" ];
      };

      # A server's ingress is nginx and SSH; everything else is closed by
      # default. Plain assignment (not mkDefault) because networking's own
      # `enable = false` needs to be the one left overridable.
      networking.firewall.enable = true;

      # Direct peer connections instead of DERP-relayed ones, for a server that
      # runs unNAT'd.
      services.tailscale.openFirewall = true;

      environment = {
        systemPackages = [
          pkgs.nfs-utils
          pkgs.openiscsi
          pkgs.dnsutils
        ];
        # Print the URL instead on servers
        variables.BROWSER = "echo";
        # Don't install the /lib/ld-linux.so.2 and /lib64/ld-linux-x86-64.so.2
        # stubs. Server users should know what they are doing.
        stub-ld.enable = lib.mkDefault false;
      };

      security.sudo = {
        # deploy-rs activates over a non-interactive SSH session, which can't
        # answer a password prompt.
        wheelNeedsPassword = false;
        # Only wheel can run the sudo binary, which blunts sudo vulnerabilities
        # such as CVE-2021-3156 for everyone else.
        execWheelOnly = true;
        # Don't lecture the user. Less mutable state.
        extraConfig = ''
          Defaults lecture = never
        '';
      };

      # Notice this also disables --help for some commands such es nixos-rebuild
      documentation = {
        enable = lib.mkDefault false;
        info.enable = lib.mkDefault false;
        man.enable = lib.mkDefault false;
        nixos.enable = lib.mkDefault false;
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
          # progress for more than 30s. For more info, see:
          #   https://utcc.utoronto.ca/~cks/space/blog/linux/SystemdShutdownWatchdog
          Manager.RebootWatchdogSec = "30s";
        };
      };
    };
}
