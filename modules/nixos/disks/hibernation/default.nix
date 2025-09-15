{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let

  cfg = config.${namespace}.disks.hibernation;
in
{
  options.${namespace}.disks.hibernation = {
    enable = mkBoolOpt false "Whether or not to enable hibernation.";
    device = mkStringOpt disks.root "The resume device name";
  };

  config = mkIf cfg.enable {
    boot = {
      kernelParams = [
        "resume_offset=533760"
      ];
      resumeDevice = "/dev/disk/by-label/${cfg.device}";
    };
  };
}
