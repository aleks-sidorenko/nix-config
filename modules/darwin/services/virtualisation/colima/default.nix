{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.colima;
in
{
  options.${namespace}.services.virtualisation.colima = with types; {
    enable = mkBoolOpt false "Enable Colima for Docker support on macOS";
    startService = mkBoolOpt true "Enable launchd service to auto-start Colima";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      user.extraGroups = [
        "docker"
      ];

      system.homebrew = {
        brews = [
          "colima"
          "docker-credential-helper"
          "docker" # Docker CLI
          "docker-compose"
        ];
      };
    };

    # Launchd service to auto-start Colima on login
    launchd.user.agents.colima = mkIf cfg.startService {
      serviceConfig = {
        Label = "com.github.colima";
        EnvironmentVariables = {
          PATH = "${homebrew.binPath}:$PATH";
        };
        ProgramArguments = [
          (homebrew.getExe "colima")
          "start"
          "--foreground"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/tmp/colima.log";
        StandardErrorPath = "/tmp/colima.error.log";
      };
    };
  };
}
