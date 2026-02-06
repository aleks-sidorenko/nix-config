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
  cfg = config.${namespace}.development.editors.cursor;
in
{
  options.${namespace}.development.editors.cursor = {
    enable = mkEnableOption "Whether to install Cursor editor";
  };

  config = mkIf cfg.enable {
    ${namespace}.development.editors.code = {
      enable = mkForce true;
      package = mkForce pkgs.code-cursor;
    };
  };
}
