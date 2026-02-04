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
    enable = mkOpt types.bool false "Whether to install Visual Studio Code.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      vscode
    ];
  };
}
