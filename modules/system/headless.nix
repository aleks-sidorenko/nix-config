{
  den.aspects.system.headless.nixos = {
    documentation = {
      enable = false;
      doc.enable = false;
      man.enable = false;
      info.enable = false;
      nixos.enable = false;
    };
    fonts.fontconfig.enable = false;
    systemd = {
      # Root is locked and no one is at the console, so the emergency shell is
      # a dead end; carrying on with the boot may still leave SSH reachable.
      enableEmergencyMode = false;
      settings.Manager = {
        # Reboots a hung host that has no one at the console to power-cycle it.
        RuntimeWatchdogSec = "30s";
        # Likewise for a shutdown that hangs before it reaches the reboot.
        RebootWatchdogSec = "30s";
      };
    };
  };
}
