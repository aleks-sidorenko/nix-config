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
    # Display sleep stays untouched: macOS keeps processes (and the VPN) running
    # with the screen off, so blanking it costs nothing.
    #
    # Idle sleep only — closing the lid sleeps the machine regardless, which
    # would need `pmset -b disablesleep 1` (no nix-darwin option). MDM may also
    # override power settings.
    power.sleep.computer = "never";
  };
}
