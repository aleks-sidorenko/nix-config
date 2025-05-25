{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.disks.boot.hibernation;
  device = config.${namespace}.disks.boot.device;
in
{
  options.${namespace}.disks.boot.hibernation = {
    enable = mkBoolOpt false "Whether or not to enable hibernation.";
  };

  config = mkIf cfg.enable {
    boot = {
      kernelParams = [
        "resume_offset=533760"
      ];
      resumeDevice = "/dev/disk/by-label/${device}";
    };
  };
}
