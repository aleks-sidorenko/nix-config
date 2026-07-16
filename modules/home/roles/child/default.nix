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
  cfg = config.${namespace}.roles.child;
in
{
  options.${namespace}.roles.child = {
    enable = mkEnableOption "Enable a restricted child account (Minecraft only, no browser)";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "The child role is only supported on NixOS (Linux) systems";
      }
    ];

    ${namespace} = {
      roles = {
        common = enabled;
      };

      # Reuse the existing Minecraft module (installs Prism Launcher).
      games.minecraft = enabled;
    };

    # No browsers, development, communication, or media. Combined with the
    # no-sudo child account, this keeps the child from installing a browser.
  };
}
