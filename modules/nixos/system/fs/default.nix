{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.fs;
in
{
  options.${namespace}.system.fs = with types; {
    enable = mkBoolOpt false "Whether to raise kernel file descriptor limits";
    maxFiles = mkOpt int 524288 "System-wide open file descriptor limit (fs.file-max)";
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      "fs.file-max" = mkDefault cfg.maxFiles;
    };
  };
}
