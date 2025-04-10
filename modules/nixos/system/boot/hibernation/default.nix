{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.system.boot.hibernation;
  device = config.${namespace}.system.boot.device;
in {
  options.${namespace}.system.boot.hibernation = {
    enable = mkBoolOpt false "Whether or not to enable hibernation.";    
  };

  config = mkIf cfg.enable {
    kernelParams = [
      "resume_offset=533760"
    ];
    resumeDevice = "/dev/disk/by-label/${device}";
  };
}
