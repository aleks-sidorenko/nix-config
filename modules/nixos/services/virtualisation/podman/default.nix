{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.virtualisation.podman;
in
{
  options.${namespace}.services.virtualisation.podman = {
    enable = mkEnableOption "Enable podman";
  };

  config = mkIf cfg.enable {

    ${namespace}.user.extraGroups = [
      "podman"
    ];

    virtualisation = {
      podman = {
        enable = true;
        dockerSocket.enable = true;
        dockerCompat = true;
        defaultNetwork.settings = {
          dns_enabled = true;
        };
      };
    };
  };
}
