{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.common;
in
{
  options.${namespace}.roles.common = {
    enable = mkEnableOption "Enable common darwin configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      system = {
        nix.enable = true;
        # macOS UI preferences (MDM may override some)
        defaults.enable = true;
        homebrew.enable = true;
      };

      cli.tools = {
        nh = {
          enable = true;
          clean.enable = true;
        };
      };

      user.enable = true;
    };
  };
}
