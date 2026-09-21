{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    roles = {
      # Use work role (includes common + homebrew + defaults)
      work = {
        enable = true;
      };

      # Always-on: long-running agent sessions, and the VPN they rely on, must
      # survive the machine being left unattended.
      agent-host = enabled;
    };

    # This machine's macOS account (declared like NixOS hosts).
    users.oleksandrsy = {
      primary = true;
      admin = true;
    };

    system.networking = {
      knownNetworkServices = [
        "Wi-Fi"
        "USB 10/100/1000 LAN"
        "ThinkPad TBT 3 Dock"
        "Thunderbolt Bridge"
      ];
    };

    services = {
      networking = {
        openvpn = {
          enable = true;
          connections.kpi = { };
        };

        socket-vmnet = {
          enable = true;
          mode = "bridged";
          interface = "en0";
        };
      };

      virtualisation.qemu = {
        enable = true;
        guests.vm = {
          cpus = 6;
          memory = "12G";
          rootDisk = "/Users/oleksandrsy/.local/share/qemu/vm/root.img";
          dataDisk = "/Users/oleksandrsy/.local/share/qemu/vm/data.img";
          mac = "52:54:00:00:00:64";
          gui = true;
        };
      };
    };
  };

  # Building the aarch64-linux guest from macOS needs a Linux builder.
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
  };

  system.stateVersion = 5;
}
