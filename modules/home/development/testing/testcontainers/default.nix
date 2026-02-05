{
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.development.testing.testcontainers;
in
{
  options.${namespace}.development.testing.testcontainers = with types; {
    enable = mkBoolOpt false "Configure environment for Testcontainers with Podman";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      DOCKER_HOST = "unix:///var/run/docker.sock";
      TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";
      TESTCONTAINERS_RYUK_DISABLED = "true";
    };
  };
}
