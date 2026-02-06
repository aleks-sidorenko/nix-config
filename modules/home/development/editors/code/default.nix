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
  cfg = config.${namespace}.development.editors.code;
in
{
  options.${namespace}.development.editors.code = {
    enable = mkEnableOption "Whether to install Visual Studio Code";
    package = mkPackageOpt pkgs.vscode "The VS Code package to use";
  };

  config = mkIf cfg.enable {

    programs.vscode = {
      enable = true;
      package = cfg.package;
    };
  };
}
