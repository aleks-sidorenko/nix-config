{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.gh;
in
{
  options.${namespace}.cli.tools.gh = with types; {
    enable = mkBoolOpt false "Whether or not to enable GitHub CLI";
  };

  config = mkIf cfg.enable {
    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };
  };
}
