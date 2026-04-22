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
  };

  config = mkIf cfg.enable {
    # Apply immediately on darwin-rebuild switch
    system.activationScripts.postActivation.text = ''
      sysctl -w kern.maxfiles=${toString cfg.maxFiles}
      sysctl -w kern.maxfilesperproc=${toString cfg.maxFilesPerProc}
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
        ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
  };
}
