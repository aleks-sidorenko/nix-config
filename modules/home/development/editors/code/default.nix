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

    languages = {
      haskell = mkEnableOption "Enable Haskell language support";
      java = mkEnableOption "Enable Java language support";
      scala = mkEnableOption "Enable Scala language support";
    };
  };

  config = mkIf cfg.enable {

    programs.vscode = {
      enable = true;
      package = cfg.package;
      profiles.default.extensions =
        optionals cfg.languages.haskell [
          pkgs.vscode-extensions.justusadam.language-haskell
          pkgs.vscode-extensions.haskell.haskell
        ]
        ++ optionals cfg.languages.java [
          pkgs.vscode-extensions.redhat.java
        ]
        ++ optionals cfg.languages.scala [
          pkgs.vscode-extensions.scalameta.metals
        ];
    };
  };
}
