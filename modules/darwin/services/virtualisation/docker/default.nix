{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.podman;
in
{
  options.${namespace}.services.virtualisation.podman = with types; {
    enable = mkBoolOpt false "Enable podman via Homebrew";
  };

  config = mkIf cfg.enable {

    ${namespace} = {

      user.extraGroups = [
        "podman"
      ];

      system.homebrew.brews = [
        "docker"
        "docker-compose"
        "docker-credential-helper"
        "podman"
      ];
    };

  };
}
