{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.desktop;
in
{
  options.${namespace}.roles.desktop = {
    enable = mkEnableOption "Enable the desktop home suite (graphical + development)";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles = {
        graphical = enabled;
        communication = enabled;
        mobile = enabled;
        gaming = enabled;
        router = enabled;
        development = {
          enable = true;
          ai = {
            copilot = false;
            claude-code = true;
          };
          languages = {
            haskell = true;
            rust = false;
            python = true;
            go = false;
            typescript = true;
          };
        };
      };
    };
  };
}
