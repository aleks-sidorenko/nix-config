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
    colima.enable = mkBoolOpt false "Set TESTCONTAINERS_HOST_OVERRIDE from Colima address";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock";
    }
    // optionalAttrs cfg.colima.enable {
      TESTCONTAINERS_HOST_OVERRIDE = "$(colima ls -j | jq -r '.address')";
    };
  };
}
