{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.homebook;
in
{
  options.${namespace}.roles.homebook = {
    enable = mkEnableOption "Enable homebook home suite (desktop without development)";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "The homebook role is only supported on NixOS (Linux) systems";
      }
    ];

    ${namespace} = {
      roles = {
        # Reuse the whole desktop home composition. development is not part of
        # the desktop suite, so a homebook simply doesn't enable it.
        desktop = enabled;
      };
    };
  };
}
