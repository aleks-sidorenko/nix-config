{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.audio;
in
{
  options.${namespace}.hardware.audio = with types; {
    enable = mkBoolOpt false "Enable or disable hardware audio support";
  };

  config = mkIf cfg.enable {
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
        jack.enable = true;
      };
      udev.packages = with pkgs; [
        headsetcontrol
      ];
    };
    security.rtkit.enable = true;
    programs.noisetorch.enable = true;

    environment.systemPackages = with pkgs; [
      headsetcontrol
      headset-charge-indicator
      pulsemixer
    ];
  };
}
