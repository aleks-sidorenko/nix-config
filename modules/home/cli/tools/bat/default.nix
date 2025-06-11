{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.bat;
in
{
  options.${namespace}.cli.tools.bat = with types; {
    enable = mkBoolOpt false "Whether or not to enable bat";
  };

  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;

      extraPackages = builtins.attrValues {
        inherit (pkgs.bat-extras)

          batgrep # search through and highlight files using ripgrep
          batdiff # Diff a file against the current git index, or display the diff between to files
          batman # read manpages using bat as the formatter
          ;
      };
    };

    home.sessionVariables = {
      MANPAGER = "batman";
    };
  };
}
