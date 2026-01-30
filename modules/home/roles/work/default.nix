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
  cfg = config.${namespace}.roles.work;
in
{
  options.${namespace}.roles.work = {
    enable = mkEnableOption "Enable work machine configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles.common = enabled; # Reuse common CLI tools

      roles.development = {
        enable = true;
        ai = {
          claude-code = true;
          copilot = false;
        };
        languages = {
          scala = true;
          java = true;
        };
      };

      cli = {
        tools = {
          k8s.enable = true;
        };
      };

      # Disable Linux-specific features
      security.sops.enable = mkForce false;
    };

  };
}
