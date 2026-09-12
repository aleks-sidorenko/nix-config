{
  config,
  lib,
  pkgs,
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

      # podman on macOS is only shipped for Apple Silicon here; Intel Macs get
      # the docker CLIs but no podman brew/group.
      user.extraGroups = optional pkgs.stdenv.isAarch64 "podman";

      system.homebrew.brews = [
        "docker"
        "docker-compose"
        "docker-credential-helper"
      ]
      ++ optional pkgs.stdenv.isAarch64 "podman";
    };

  };
}
