{
  den.aspects.system.headless.nixos =
    { lib, ... }:
    {
      documentation = {
        enable = false;
        doc.enable = false;
        man.enable = false;
        info.enable = false;
        nixos.enable = false;
      };
      # A default: an aspect that renders text (a headless browser) turns it back on.
      fonts.fontconfig.enable = lib.mkDefault false;
      # Without a display, a browser launch has nothing to open; echo prints the URL.
      environment = {
        stub-ld.enable = false;
        variables.BROWSER = "echo";
      };
      systemd = {
        # Root is locked and no one is at the console, so the emergency shell is
        # a dead end; carrying on with the boot may still leave SSH reachable.
        enableEmergencyMode = false;
        settings.Manager = {
          # Reboots a hung host that has no one at the console to power-cycle it.
          RuntimeWatchdogSec = "20s";
          # Likewise for a shutdown that hangs before it reaches the reboot.
          RebootWatchdogSec = "30s";
        };
      };
    };
}
