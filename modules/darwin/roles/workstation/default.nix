{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.workstation;
in
{
  options.${namespace}.roles.workstation = with types; {
    enable = mkEnableOption "Enable workstation configuration";

    homebrew = {
      casks = mkOpt (listOf str) [ ] "Additional Homebrew casks";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Inherit common configuration
      roles.common = enabled;

      # Homebrew for GUI apps (casks configured per-host)
      system.homebrew = {
        enable = true;
        casks = cfg.homebrew.casks;
      };
    };
  };
}
