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
  cfg = config.${namespace}.development.scala;
in
{
  options.${namespace}.development.scala = {
    enable = mkOpt types.bool false "Whether to configure Scala development.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      scala_3
      sbt
      metals # Scala LSP server
      coursier # Scala package manager
      scalafmt # Formatter
    ];
  };
}
