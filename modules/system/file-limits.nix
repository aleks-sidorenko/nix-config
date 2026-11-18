let
  limit = toString 524288;
in
{
  den.aspects.system.file-limits.darwin = {
    # Takes effect now, without waiting for a reboot.
    system.activationScripts.postActivation.text = ''
      sysctl -w kern.maxfiles=${limit}
      sysctl -w kern.maxfilesperproc=${limit}
      sysctl -w kern.maxvnodes=${limit}
      launchctl limit maxfiles ${limit} ${limit}
    '';

    # macOS does not reliably honor /etc/sysctl.conf.
    launchd.daemons.sysctl-fs-limits.serviceConfig = {
      Label = "org.nix-config.sysctl-fs-limits";
      ProgramArguments = [
        "/usr/sbin/sysctl"
        "-w"
        "kern.maxfiles=${limit}"
        "kern.maxfilesperproc=${limit}"
        "kern.maxvnodes=${limit}"
      ];
      RunAtLoad = true;
      KeepAlive = false;
    };

    # launchd keeps its own RLIMIT_NOFILE, separate from kern.maxfilesperproc,
    # that every launchd-spawned process inherits; its low default still lets
    # tools like node hit EMFILE.
    launchd.daemons.launchctl-maxfiles.serviceConfig = {
      Label = "org.nix-config.launchctl-maxfiles";
      ProgramArguments = [
        "/bin/launchctl"
        "limit"
        "maxfiles"
        limit
        limit
      ];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
