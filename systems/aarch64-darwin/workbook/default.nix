{
  lib,
  config,
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

        # The guest's identity is its tailnet name, so it no longer needs a LAN
        # address — and bridged mode fails on networks that lease to a single
        # MAC per client.
        socket-vmnet = {
          enable = true;
          mode = "shared";
        };
      };

      virtualisation.qemu = {
        enable = true;
        guests.server-vm = {
          cpus = 4;
          memory = "8G";
          rootDisk = "${homeDir config}/.local/share/qemu/server-vm/root.qcow2";
          dataDisk = "${homeDir config}/.local/share/qemu/server-vm/data.qcow2";
          varsDisk = "${homeDir config}/.local/share/qemu/server-vm/vars.img";
          mac = "52:54:00:00:00:64";
          display = "none";
        };
      };
    };
  };

  # Building the aarch64-linux guest from macOS needs a Linux builder. disko
  # runs its own VM inside this one with no nested virtualisation, so that
  # inner build is emulated and wants real cores; the disk has to hold the
  # guest's images, and is kept across restarts so a rebuild is not a rebuild
  # of everything. maxJobs follows virtualisation.cores on its own.
  nix.linux-builder = {
    enable = true;
    config.virtualisation = {
      cores = 8;
      darwin-builder = {
        memorySize = 16 * 1024;
        diskSize = 120 * 1024;
      };
    };
  };

  system.stateVersion = 5;
}
