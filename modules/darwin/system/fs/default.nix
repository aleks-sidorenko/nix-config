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
    maxFiles = mkOpt int 524288 "System-wide open file limit (kern.maxfiles)";
    maxFilesPerProc = mkOpt int 524288 "Per-process open file limit (kern.maxfilesperproc)";
    maxVnodes = mkOpt int 524288 "Kernel vnode cache size (kern.maxvnodes)";
    launchdMaxFiles = mkOpt int 524288 "launchd per-process RLIMIT_NOFILE (launchctl limit maxfiles)";
  };

  config = mkIf cfg.enable {
    # Apply immediately on darwin-rebuild switch
    system.activationScripts.postActivation.text = ''
      sysctl -w kern.maxfiles=${toString cfg.maxFiles}
      sysctl -w kern.maxfilesperproc=${toString cfg.maxFilesPerProc}
      sysctl -w kern.maxvnodes=${toString cfg.maxVnodes}
      launchctl limit maxfiles ${toString cfg.launchdMaxFiles} ${toString cfg.launchdMaxFiles}
    '';

    # Persist across reboots (macOS does not reliably honor /etc/sysctl.conf)
    launchd.daemons.sysctl-fs-limits = {
      serviceConfig = {
        Label = "org.nix-config.sysctl-fs-limits";
        ProgramArguments = [
          "/usr/sbin/sysctl"
          "-w"
          "kern.maxfiles=${toString cfg.maxFiles}"
          "kern.maxfilesperproc=${toString cfg.maxFilesPerProc}"
          "kern.maxvnodes=${toString cfg.maxVnodes}"
        ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };

    # launchctl maintains its own per-process RLIMIT_NOFILE that all
    # launchd-spawned processes (i.e. every GUI/CLI app) inherit. It is
    # separate from kern.maxfilesperproc and defaults to 200000 soft, so
    # tools like Node.js can still hit EMFILE — often surfaced as
    # "ENFILE: file table overflow" in error messages — despite the
    # kernel limits being high.
    launchd.daemons.launchctl-maxfiles = {
      serviceConfig = {
        Label = "org.nix-config.launchctl-maxfiles";
        ProgramArguments = [
          "/bin/launchctl"
          "limit"
          "maxfiles"
          (toString cfg.launchdMaxFiles)
          (toString cfg.launchdMaxFiles)
        ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
  };
}
