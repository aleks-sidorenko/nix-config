{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.networking.socket-vmnet;
in
{
  options.${namespace}.services.networking.socket-vmnet = with types; {
    enable = mkBoolOpt false "Whether to run socket_vmnet, exposing vmnet.framework to unprivileged VMs";
    mode = mkOpt (enum [
      "bridged"
      "shared"
    ]) "bridged" "vmnet mode: bridged puts guests on the host LAN, shared NATs them";
    interface = mkOpt str "en0" "Host interface to bridge onto (ignored in shared mode)";
    socket =
      mkOpt str "/var/run/socket_vmnet.${cfg.mode}"
        "Unix socket guests connect through (read-only)";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.${namespace}.system.homebrew.enable;
        message = "${namespace}.services.networking.socket-vmnet needs ${namespace}.system.homebrew: socket_vmnet is not in nixpkgs.";
      }
    ];

    ${namespace}.system.homebrew.brews = [ "socket_vmnet" ];

    # vmnet bridged mode needs root, but no Apple entitlement — which is why
    # guests reach it through this socket instead of attaching directly.
    #
    # Accepted risk: the binary lives in a user-writable Homebrew prefix and is
    # started as root, so anyone who can write there can run code as root. This
    # is how upstream ships it (`sudo brew services start socket_vmnet`); the
    # alternative is packaging socket_vmnet in nixpkgs.
    launchd.daemons.socket-vmnet = {
      serviceConfig = {
        ProgramArguments = [
          (homebrew.getOptExe "socket_vmnet" "socket_vmnet")
          "--vmnet-mode=${cfg.mode}"
        ]
        ++ optional (cfg.mode == "bridged") "--vmnet-interface=${cfg.interface}"
        ++ [ cfg.socket ];

        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/socket-vmnet.log";
        StandardErrorPath = "/var/log/socket-vmnet.log";
      };
    };
  };
}
