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
  # Darwin counterpart of modules/nixos/system/power: same option path, so
  # `nix-config.system.power.mode` means the same thing on both platforms and is
  # set by the same role (roles.agent-host).
  options.${namespace}.system.power = with types; {
    mode =
      mkOpt
        (enum [
          "no-sleep"
          "default"
        ])
        "default"
        "Power behavior: 'no-sleep' inhibits idle sleep (always-on hosts); 'default' leaves normal behavior.";
  };

  config = mkIf (cfg.mode == "no-sleep") {
    # Applied by nix-darwin as `systemsetup -setComputerSleep never`. Display
    # sleep is left alone on purpose: macOS keeps processes (and the VPN)
    # running while the screen is off, so blanking it costs nothing.
    #
    # Two caveats, both out of scope here: closing the lid still sleeps the
    # machine regardless of this timer (that needs `pmset -b disablesleep 1`,
    # which nix-darwin exposes no option for), and MDM policies may override
    # power settings, same hedge as system.defaults.
    power.sleep.computer = "never";
  };
}
