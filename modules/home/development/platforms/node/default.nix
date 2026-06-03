{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.development.platforms.node;
  nodejs = if cfg.version == "20" then pkgs.nodejs_20 else pkgs.nodejs_22;
in
{
  options.${namespace}.development.platforms.node = {
    enable = mkEnableOption "Whether or not to enable Node.js platform";
    version = mkStringOpt "22" "Node.js major version (20 or 22)";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    };

    home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

    home.packages = [ nodejs ];
  };
}
