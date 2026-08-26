{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.power;
in
{
  # Owns sleep/suspend inhibition. See modules/nixos/system/hibernation for the
  # (complementary) resume-device configuration.
  options.${namespace}.system.power = with types; {
    mode =
      mkOpt
        (enum [
          "no-sleep"
          "default"
        ])
        "default"
        "Power behavior: 'no-sleep' inhibits all suspend/hibernate (always-on hosts); 'default' leaves normal behavior.";
  };

  config = mkIf (cfg.mode == "no-sleep") {
    # DE-independent guards: mask the sleep targets and stop logind suspending on
    # idle/lid/power-key. GNOME's own power daemon is handled in the GNOME home
    # module, which reads this same option.
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
    };
  };
}
