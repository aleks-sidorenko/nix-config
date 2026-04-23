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
    inotify = {
      maxUserWatches = mkOpt int 524288 "Per-user inotify watch limit (fs.inotify.max_user_watches)";
      maxUserInstances = mkOpt int 256 "Per-user inotify instance limit (fs.inotify.max_user_instances)";
    };
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      "fs.file-max" = cfg.maxFiles;
      "fs.inotify.max_user_watches" = cfg.inotify.maxUserWatches;
      "fs.inotify.max_user_instances" = cfg.inotify.maxUserInstances;
    };
  };
}
