{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let

  cfg = config.${namespace}.system.hibernation;
in
{
  options.${namespace}.system.hibernation = {
    enable = mkBoolOpt false "Whether or not to enable hibernation";
    device = mkStringOpt defaults.disks.root "The resume device name";
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
