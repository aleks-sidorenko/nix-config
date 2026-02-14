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

    languages = {
      haskell = mkEnableOption "Enable Haskell language support";
      java = mkEnableOption "Enable Java language support";
      scala = mkEnableOption "Enable Scala language support";
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.development.editors.code = {
      enable = mkForce true;
      package = mkForce pkgs.code-cursor;
      languages = {
        haskell = mkForce cfg.languages.haskell;
        java = mkForce cfg.languages.java;
        scala = mkForce cfg.languages.scala;
      };
    };
  };
}
