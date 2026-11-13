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
    # Reboots a hung host that has no one at the console to power-cycle it.
    systemd.settings.Manager.RuntimeWatchdogSec = "30s";
  };
}
