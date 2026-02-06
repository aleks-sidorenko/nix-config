{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.docker;
in
{
  options.${namespace}.services.virtualisation.docker = with types; {
    enable = mkBoolOpt false "Enable Docker CLI support on macOS";

  };

  config = mkIf cfg.enable {
    ${namespace} = {
      user.extraGroups = [
        "docker"
      ];

      system.homebrew = {
        brews = [
          "docker-credential-helper"
          "docker" # Docker CLI
          "docker-compose"
        ];
      };
    };
  };

}
