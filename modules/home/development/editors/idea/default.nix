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
  cfg = config.${namespace}.development.editors.idea;
in
{
  options.${namespace}.development.editors.idea = {
    enable = mkOpt types.bool false "Whether to install JetBrains IDEA.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      jetbrains.idea
    ];
  };
}
